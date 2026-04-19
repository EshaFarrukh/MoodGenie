import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../src/theme/app_theme.dart';
import '../../src/services/secure_operations_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String? therapistId;
  final String? therapistName;
  final String? roomId;
  final bool isTherapist;
  final bool audioOnly;
  final bool initiatesCall;

  const VideoCallScreen({
    super.key,
    this.therapistId,
    this.therapistName,
    this.roomId,
    this.isTherapist = false,
    this.audioOnly = false,
    this.initiatesCall = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final SecureOperationsService _secureOperations = SecureOperationsService();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<RTCIceCandidate> _pendingRemoteCandidates = <RTCIceCandidate>[];

  String? _callRoomId;
  DocumentReference<Map<String, dynamic>>? _roomRef;
  late String _currentUserId;
  bool _isCaller = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isEnding = false;
  bool _isPreparingRoom = true;
  String _connectionLabel = 'Connecting...';
  String? _roomError;
  late bool _audioOnly;
  bool _remoteDescriptionApplied = false;
  bool _roomListenersAttached = false;
  bool _localAnswerPublished = false;
  final List<String> _diagnosticEntries = <String>[];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _audioOnly = widget.audioOnly;
    _isVideoOff = _audioOnly;
    _prepareCallRoomAndInitialize();
  }

  Future<void> _prepareCallRoomAndInitialize() async {
    try {
      if (widget.roomId != null && widget.roomId!.isNotEmpty) {
        _callRoomId = widget.roomId!;
        _logCallStage(
          'Room ensured.',
          details: {'roomId': _callRoomId},
        );
      } else if (widget.therapistId != null && widget.therapistId!.isNotEmpty) {
        _logCallStage(
          'Ensuring secure room from counterpart context.',
          details: {
            'counterpartId': widget.therapistId,
            'audioOnly': _audioOnly,
          },
        );
        final room = await _secureOperations.ensureCallRoom(
          counterpartId: widget.therapistId!,
          audioOnly: _audioOnly,
        );
        _callRoomId = room.roomId;
        _logCallStage(
          'Room ensured.',
          details: {
            'roomId': room.roomId,
            'appointmentId': room.appointmentId,
          },
        );
      } else {
        throw Exception('Unable to prepare call room for this session.');
      }

      _roomRef = FirebaseFirestore.instance
          .collection('calls')
          .doc(_callRoomId!);

      if (!mounted) {
        return;
      }

      setState(() {
        _roomError = null;
        _connectionLabel = 'Preparing media...';
      });

      await _initWebRTC();

      if (!mounted) {
        return;
      }
      setState(() => _isPreparingRoom = false);
    } catch (error) {
      _logCallStage(
        'Call preparation failed.',
        details: {'error': error.toString()},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparingRoom = false;
        _roomError = 'Failed to prepare secure call: $error';
        _connectionLabel = 'Call unavailable';
      });
    }
  }

  Future<void> _initWebRTC() async {
    final roomRef = _roomRef!;
    _logCallStage('Initializing renderers.');
    await Future.wait<void>([
      _localRenderer.initialize(),
      _remoteRenderer.initialize(),
    ]);

    _logCallStage(
      'Requesting local media.',
      details: {'audioOnly': _audioOnly},
    );
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': _audioOnly ? false : {'facingMode': 'user'},
      });
      _logCallStage(
        'Local media acquired.',
        details: {
          'audioTracks': _localStream?.getAudioTracks().length ?? 0,
          'videoTracks': _localStream?.getVideoTracks().length ?? 0,
        },
      );
    } catch (error) {
      throw Exception(
        'Unable to access ${_audioOnly ? 'microphone' : 'camera or microphone'}: $error',
      );
    }

    _localRenderer.srcObject = _localStream;

    _logCallStage('Loading signaling room snapshot.');
    final roomSnapshot = await roomRef.get();
    final roomData = roomSnapshot.data();
    final roomStatus = _readString(roomData?['status']) ?? 'missing';
    final roomCallerId = _readString(roomData?['callerId']);
    final hasOffer = _isSessionDescriptionPayload(roomData?['offer']);
    final activeOfferFromOtherParticipant =
        roomSnapshot.exists &&
        roomStatus != 'ended' &&
        hasOffer &&
        roomCallerId != null &&
        roomCallerId != _currentUserId;
    final roomAudioOnly = _readBool(roomData?['audioOnly']);

    _logCallStage(
      'Room snapshot loaded.',
      details: {
        'exists': roomSnapshot.exists,
        'status': roomStatus,
        'hasOffer': hasOffer,
        'callerId': roomCallerId,
        'roomAudioOnly': roomAudioOnly,
        'initiatesCall': widget.initiatesCall,
      },
    );

    if (activeOfferFromOtherParticipant) {
      if (roomAudioOnly != null && roomAudioOnly != _audioOnly) {
        _logCallStage(
          'Aligning call mode with active room state.',
          details: {'requestedAudioOnly': _audioOnly, 'roomAudioOnly': roomAudioOnly},
        );
        _audioOnly = roomAudioOnly;
        _isVideoOff = _audioOnly;
      }
      _connectionLabel = _audioOnly
          ? 'Joining secure audio call...'
          : 'Joining secure video call...';
      _isCaller = false;
      await _joinCall(roomData);
      return;
    }

    _connectionLabel = _audioOnly
        ? 'Starting secure audio call...'
        : 'Starting secure video call...';
    if (!roomSnapshot.exists || roomStatus == 'ended' || !hasOffer || widget.initiatesCall) {
      _isCaller = true;
      await _createOffer(roomData);
    } else {
      _isCaller = false;
      await _joinCall(roomData);
    }
  }

  Future<void> _createPeerConnection() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        ..._buildTurnServers(),
      ],
    };

    _peerConnection = await createPeerConnection(configuration);
    _logCallStage(
      'Peer connection created.',
      details: {'hasTurn': _buildTurnServers().isNotEmpty},
    );
    _remoteDescriptionApplied = false;
    _pendingRemoteCandidates.clear();
    _roomListenersAttached = false;
    _localAnswerPublished = false;

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isEmpty || !mounted) {
        return;
      }
      _logCallStage(
        'Remote media track received.',
        details: {'streamCount': event.streams.length},
      );
      setState(() {
        _remoteRenderer.srcObject = event.streams[0];
        _connectionLabel = 'Connected';
      });
    };

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      _logCallStage(
        'Publishing local ICE candidate.',
        details: {
          'role': _isCaller ? 'caller' : 'callee',
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
      _roomRef!
          .collection(_isCaller ? 'callerCandidates' : 'calleeCandidates')
          .add(candidate.toMap());
    };

    _peerConnection?.onConnectionState = (state) {
      if (!mounted) {
        return;
      }
      setState(() {
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _connectionLabel = 'Connected';
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
            _connectionLabel = 'Connecting...';
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            _connectionLabel = 'Reconnecting...';
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            _connectionLabel = 'Connection failed';
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _connectionLabel = 'Call ended';
            break;
          default:
            _connectionLabel = 'Connecting...';
        }
      });
      _logCallStage(
        'Peer connection state changed.',
        details: {'state': state.name, 'label': _connectionLabel},
      );
    };
  }

  void _attachRoomListeners() {
    if (_roomListenersAttached) {
      _logCallStage('Skipping duplicate signaling listener attachment.');
      return;
    }
    _roomListenersAttached = true;
    final roomRef = _roomRef!;
    _logCallStage(
      'Attaching signaling listeners.',
      details: {'role': _isCaller ? 'caller' : 'callee'},
    );
    _subscriptions.add(
      roomRef.snapshots().listen((snapshot) async {
        final data = snapshot.data();
        if (data != null &&
            data['status'] == 'ended' &&
            mounted &&
            !_isEnding) {
          _logCallStage('Remote side ended the call.');
          await _disposeCallResources();
          if (mounted) {
            Navigator.pop(context);
          }
          return;
        }
        if (_isCaller &&
            data != null &&
            _isSessionDescriptionPayload(data['answer'])) {
          _logCallStage('Answer detected in signaling room.');
          await _applyRemoteDescription(
            RTCSessionDescription(
              data['answer']['sdp'],
              data['answer']['type'],
            ),
          );
        }
        if (!_isCaller &&
            data != null &&
            !_localAnswerPublished &&
            _isSessionDescriptionPayload(data['offer'])) {
          _logCallStage('Offer detected for callee.');
          await _answerOffer(
            RTCSessionDescription(
              data['offer']['sdp'],
              data['offer']['type'],
            ),
          );
        }
      }),
    );

    _subscriptions.add(
      roomRef
          .collection(_isCaller ? 'calleeCandidates' : 'callerCandidates')
          .snapshots()
          .listen((snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type != DocumentChangeType.added) {
                continue;
              }
              final data = change.doc.data();
              if (data == null) {
                continue;
              }
              _logCallStage(
                'Remote ICE candidate received.',
                details: {
                  'role': _isCaller ? 'caller' : 'callee',
                  'sdpMid': data['sdpMid'],
                  'sdpMLineIndex': data['sdpMLineIndex'],
                },
              );
              _addOrBufferRemoteCandidate(
                RTCIceCandidate(
                  data['candidate'],
                  data['sdpMid'],
                  data['sdpMLineIndex'],
                ),
              );
            }
          }),
    );
  }

  Future<void> _applyRemoteDescription(
    RTCSessionDescription description,
  ) async {
    final currentRemoteDesc = await _peerConnection?.getRemoteDescription();
    if (currentRemoteDesc != null) {
      _logCallStage(
        'Skipping remote description because one is already applied.',
        details: {'type': currentRemoteDesc.type},
      );
      return;
    }
    _logCallStage(
      'Applying remote description.',
      details: {'type': description.type},
    );
    await _peerConnection?.setRemoteDescription(description);
    _logCallStage(
      'Remote description set.',
      details: {'type': description.type},
    );
    _remoteDescriptionApplied = true;
    await _flushBufferedCandidates();
  }

  void _addOrBufferRemoteCandidate(RTCIceCandidate candidate) {
    if (_remoteDescriptionApplied) {
      _logCallStage('Applying remote ICE candidate immediately.');
      _peerConnection?.addCandidate(candidate);
      return;
    }
    _logCallStage('Buffering remote ICE candidate until remote description is ready.');
    _pendingRemoteCandidates.add(candidate);
  }

  Future<void> _flushBufferedCandidates() async {
    _logCallStage(
      'Flushing buffered ICE candidates.',
      details: {'count': _pendingRemoteCandidates.length},
    );
    while (_pendingRemoteCandidates.isNotEmpty) {
      final candidate = _pendingRemoteCandidates.removeAt(0);
      await _peerConnection?.addCandidate(candidate);
    }
  }

  List<Map<String, dynamic>> _buildTurnServers() {
    const rawTurnUrls = String.fromEnvironment('TURN_URLS');
    const turnUsername = String.fromEnvironment('TURN_USERNAME');
    const turnCredential = String.fromEnvironment('TURN_CREDENTIAL');

    final urls = rawTurnUrls
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (urls.isEmpty) {
      return const [];
    }

    return [
      {
        'urls': urls,
        if (turnUsername.isNotEmpty) 'username': turnUsername,
        if (turnCredential.isNotEmpty) 'credential': turnCredential,
      },
    ];
  }

  Future<void> _createOffer(Map<String, dynamic>? roomData) async {
    await _createPeerConnection();
    _attachRoomListeners();
    await _resetRoomForFreshOffer();

    _logCallStage(
      'Creating offer.',
      details: {'audioOnly': _audioOnly},
    );
    final offer = await _peerConnection!.createOffer();
    _logCallStage(
      'Offer created.',
      details: {'type': offer.type},
    );
    await _peerConnection!.setLocalDescription(offer);
    _logCallStage(
      'Local description set.',
      details: {'type': offer.type},
    );

    final roomRef = _roomRef!;
    await roomRef.set({
      'offer': offer.toMap(),
      'status': 'calling',
      'callerId': _currentUserId,
      'audioOnly': _audioOnly,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) {
      setState(() {
        _connectionLabel = _audioOnly
            ? 'Waiting for participant to join audio call...'
            : 'Waiting for participant to join video call...';
      });
    }
    _logCallStage('Offer published to signaling room.');
  }

  Future<void> _joinCall(Map<String, dynamic>? roomData) async {
    await _createPeerConnection();
    _attachRoomListeners();

    final roomRef = _roomRef!;
    final data = roomData;

    if (data != null && _isSessionDescriptionPayload(data['offer'])) {
      await _answerOffer(
        RTCSessionDescription(data['offer']['sdp'], data['offer']['type']),
      );
      return;
    }

    _logCallStage('Joiner is waiting for a fresh offer.');
    await roomRef.set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _hangUp() async {
    if (_isEnding) {
      return;
    }
    _isEnding = true;

    try {
      if (_callRoomId != null) {
        _logCallStage('Ending call and updating signaling room.');
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(_callRoomId!)
            .set({
              'status': 'ended',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (_) {
      // Best-effort signaling cleanup. Media teardown still continues.
    }

    await _disposeCallResources();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleMic() {
    if (_isPreparingRoom || _roomError != null) {
      return;
    }
    setState(() {
      _isMuted = !_isMuted;
      _localStream?.getAudioTracks().forEach(
        (track) => track.enabled = !_isMuted,
      );
    });
  }

  void _toggleVideo() {
    if (_isPreparingRoom || _roomError != null) {
      return;
    }
    setState(() {
      _isVideoOff = !_isVideoOff;
      _localStream?.getVideoTracks().forEach(
        (track) => track.enabled = !_isVideoOff,
      );
    });
  }

  Future<void> _disposeCallResources() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _pendingRemoteCandidates.clear();
    _remoteDescriptionApplied = false;
    _roomListenersAttached = false;
    _localAnswerPublished = false;

    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;

    await _peerConnection?.close();
    _peerConnection = null;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }

  Future<void> _answerOffer(RTCSessionDescription offer) async {
    if (_localAnswerPublished) {
      _logCallStage('Skipping duplicate answer publish.');
      return;
    }

    _logCallStage('Answering remote offer.');
    await _applyRemoteDescription(offer);

    final answer = await _peerConnection!.createAnswer();
    _logCallStage(
      'Answer created.',
      details: {'type': answer.type},
    );
    await _peerConnection!.setLocalDescription(answer);
    _logCallStage(
      'Local description set.',
      details: {'type': answer.type},
    );

    await _roomRef!.update({
      'answer': answer.toMap(),
      'status': 'connected',
      'audioOnly': _audioOnly,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _localAnswerPublished = true;
    _logCallStage('Answer published to signaling room.');
  }

  Future<void> _resetRoomForFreshOffer() async {
    final roomRef = _roomRef!;
    _logCallStage('Resetting stale signaling state for new offer.');
    await Future.wait<void>([
      _clearCandidateCollection('callerCandidates'),
      _clearCandidateCollection('calleeCandidates'),
    ]);

    await roomRef.set({
      'offer': FieldValue.delete(),
      'answer': FieldValue.delete(),
      'callerId': FieldValue.delete(),
      'status': 'ready',
      'audioOnly': _audioOnly,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _clearCandidateCollection(String collectionName) async {
    final snapshot = await _roomRef!.collection(collectionName).get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    _logCallStage(
      'Cleared candidate collection.',
      details: {'collection': collectionName, 'count': snapshot.docs.length},
    );
  }

  bool _isSessionDescriptionPayload(dynamic value) {
    if (value is! Map) {
      return false;
    }
    final dynamic sdp = value['sdp'];
    final dynamic type = value['type'];
    return sdp is String &&
        sdp.trim().isNotEmpty &&
        type is String &&
        type.trim().isNotEmpty;
  }

  String? _readString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }

  bool? _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }

  void _logCallStage(String message, {Map<String, Object?> details = const {}}) {
    if (!kDebugMode) {
      return;
    }
    final roomLabel = _callRoomId ?? widget.roomId ?? 'pending_room';
    final payload = <String, Object?>{
      'roomId': roomLabel,
      'currentUserId': _currentUserId,
      'audioOnly': _audioOnly,
      ...details,
    };
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final detailText = details.isEmpty
        ? ''
        : ' · ${details.entries.map((entry) => '${entry.key}=${entry.value}').join(', ')}';
    final entry = '$timestamp  $message$detailText';
    if (mounted) {
      setState(() {
        _diagnosticEntries.insert(0, entry);
        if (_diagnosticEntries.length > 8) {
          _diagnosticEntries.removeRange(8, _diagnosticEntries.length);
        }
      });
    } else {
      _diagnosticEntries.insert(0, entry);
      if (_diagnosticEntries.length > 8) {
        _diagnosticEntries.removeRange(8, _diagnosticEntries.length);
      }
    }
    debugPrint('[MoodGenieCall] $message :: $payload');
  }

  @override
  Widget build(BuildContext context) {
    final participantName = widget.therapistName ?? 'Participant';
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video (Full Screen) or Audio-Only Avatar
          Positioned.fill(
            child: _roomError != null
                ? _buildErrorState()
                : _isPreparingRoom
                ? _buildPreparingState()
                : _audioOnly
                ? Container(
                    color: const Color(0xFF1A1A2E),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.accentCyan,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                participantName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            participantName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _connectionLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _remoteRenderer.srcObject != null
                ? RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.accentCyan,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _connectionLabel == 'Connected'
                              ? '$participantName is on the call'
                              : 'Waiting for $participantName...',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
          ),

          // Local Video (PiP) — hidden in audio-only mode
          if (!_audioOnly && !_isPreparingRoom && _roomError == null)
            Positioned(
              top: 60,
              right: 20,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryMid, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: !_isVideoOff
                      ? RTCVideoView(_localRenderer, mirror: true)
                      : const Center(
                          child: Icon(
                            Icons.videocam_off,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                ),
              ),
            ),

          // Top Bar Overlay
          Positioned(
            top: 36,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  _buildTopButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: _hangUp,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            participantName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _roomError == null
                                ? _connectionLabel
                                : 'Call unavailable',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Controls
          if (!_isPreparingRoom && _roomError == null)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: _isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      color: _isMuted ? Colors.white24 : Colors.white,
                      iconColor: _isMuted ? Colors.white : Colors.black,
                      onTap: _toggleMic,
                    ),
                    _buildControlButton(
                      icon: Icons.call_end_rounded,
                      label: 'End',
                      color: Colors.red,
                      iconColor: Colors.white,
                      size: 70,
                      onTap: _hangUp,
                    ),
                    if (!_audioOnly)
                      _buildControlButton(
                        icon: _isVideoOff
                            ? Icons.videocam_off_rounded
                            : Icons.videocam_rounded,
                        label: _isVideoOff ? 'Camera off' : 'Camera',
                        color: _isVideoOff ? Colors.white24 : Colors.white,
                        iconColor: _isVideoOff ? Colors.white : Colors.black,
                        onTap: _toggleVideo,
                      )
                    else
                      const SizedBox(width: 56),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: iconColor, size: size * 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildPreparingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(color: AppColors.accentCyan),
          SizedBox(height: 16),
          Text(
            'Preparing a secure call room...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.call_end_rounded, color: Colors.white70, size: 56),
            const SizedBox(height: 16),
            const Text(
              'We could not start this call.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _roomError ?? 'Call unavailable.',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
