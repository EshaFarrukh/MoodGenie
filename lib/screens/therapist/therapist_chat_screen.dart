import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../src/services/secure_operations_service.dart';
import '../../src/theme/app_background.dart';
import '../../src/theme/app_theme.dart';
import 'video_call_screen.dart';
import 'widgets/therapist_ui.dart';

class TherapistChatScreen extends StatefulWidget {
  const TherapistChatScreen({
    super.key,
    required this.therapistId,
    required this.therapistName,
  });

  final String therapistId;
  final String therapistName;

  @override
  State<TherapistChatScreen> createState() => _TherapistChatScreenState();
}

class _TherapistChatScreenState extends State<TherapistChatScreen>
    with TickerProviderStateMixin {
  static const int _livePageSize = 40;
  static const int _historyPageSize = 30;

  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SecureOperationsService _secureOperations = SecureOperationsService();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messagesSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _activeCallSubscription;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _liveMessages =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _olderMessages =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  bool _isRecording = false;
  bool _isSending = false;
  bool _isPreparingRoom = true;
  bool _isLoadingHistory = false;
  bool _isInitialMessageLoad = true;
  bool _hasMoreMessages = true;
  bool _canStartCalls = false;
  bool _hasIncomingCall = false;
  bool _incomingCallAudioOnly = false;
  String? _playingAudioUrl;
  String? _roomError;
  String? _callAppointmentId;
  String? _activeCallRoomId;
  late AnimationController _recordPulse;

  late String _chatRoomId;
  late String _currentUserId;
  QueryDocumentSnapshot<Map<String, dynamic>>? _oldestLoadedDoc;

  String get _displayName {
    final normalized = _coerceChatString(widget.therapistName);
    return normalized == null || normalized.isEmpty ? 'Therapist' : normalized;
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ids = [_currentUserId, widget.therapistId]..sort();
    _chatRoomId = ids.join('_');

    _recordPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() => _playingAudioUrl = null);
    });
    _scrollController.addListener(_handleScroll);
    _primeChatRoom();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _activeCallSubscription?.cancel();
    _msgController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _focusNode.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _playerCompleteSubscription?.cancel();
    _recordPulse.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _messageDocs {
    if (_olderMessages.isEmpty) {
      return _liveMessages;
    }
    final liveIds = _liveMessages.map((doc) => doc.id).toSet();
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[
      ..._liveMessages,
      ..._olderMessages.where((doc) => !liveIds.contains(doc.id)),
    ];
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _isPreparingRoom ||
        _isLoadingHistory ||
        !_hasMoreMessages) {
      return;
    }
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 240) {
      return;
    }
    _loadOlderMessages();
  }

  Future<void> _primeChatRoom() async {
    setState(() {
      _isPreparingRoom = true;
      _roomError = null;
    });

    try {
      final room = await _secureOperations.ensureTherapistChatRoom(
        counterpartId: widget.therapistId,
      );
      if (!mounted) {
        return;
      }

      _chatRoomId = room.roomId;
      _canStartCalls = room.canCall;
      _callAppointmentId = room.appointmentId;
      await _subscribeToActiveCallRoom();
      await _subscribeToRecentMessages();

      if (!mounted) {
        return;
      }
      setState(() {
        _roomError = null;
        _isPreparingRoom = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _roomError = error.toString();
        _isPreparingRoom = false;
        _isInitialMessageLoad = false;
        _hasIncomingCall = false;
        _activeCallRoomId = null;
      });
    }
  }

  Future<void> _subscribeToActiveCallRoom() async {
    await _activeCallSubscription?.cancel();
    _activeCallSubscription = null;

    final appointmentId = _callAppointmentId;
    if (!_canStartCalls || appointmentId == null || appointmentId.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasIncomingCall = false;
        _activeCallRoomId = null;
      });
      return;
    }

    final roomId = 'call_${appointmentId.trim()}';
    _activeCallSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(roomId)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          final status = _coerceChatString(data?['status']);
          final callerId = _coerceChatString(data?['callerId']);
          final hasOffer = _hasSessionDescription(data?['offer']);
          final showIncomingJoin = snapshot.exists &&
              hasOffer &&
              callerId != null &&
              callerId != _currentUserId &&
              status != 'ended';

          if (!mounted) {
            return;
          }

          setState(() {
            _activeCallRoomId = showIncomingJoin ? roomId : null;
            _hasIncomingCall = showIncomingJoin;
            _incomingCallAudioOnly = _coerceChatBool(data?['audioOnly']);
          });
        });
  }

  Future<void> _subscribeToRecentMessages() async {
    await _messagesSubscription?.cancel();
    _liveMessages.clear();
    _olderMessages.clear();
    _oldestLoadedDoc = null;
    _hasMoreMessages = true;
    _isInitialMessageLoad = true;

    final stream = FirebaseFirestore.instance
        .collection('therapist_chats')
        .doc(_chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_livePageSize)
        .snapshots();

    _messagesSubscription = stream.listen((snapshot) {
      if (!mounted) {
        return;
      }
      setState(() {
        _liveMessages
          ..clear()
          ..addAll(snapshot.docs);
        _olderMessages.removeWhere(
          (olderDoc) =>
              _liveMessages.any((liveDoc) => liveDoc.id == olderDoc.id),
        );
        _oldestLoadedDoc = _olderMessages.isNotEmpty
            ? _olderMessages.last
            : (_liveMessages.isNotEmpty ? _liveMessages.last : null);
        _hasMoreMessages = snapshot.docs.length >= _livePageSize;
        _isInitialMessageLoad = false;
      });
    });
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingHistory || !_hasMoreMessages || _oldestLoadedDoc == null) {
      return;
    }

    setState(() => _isLoadingHistory = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('therapist_chats')
          .doc(_chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_oldestLoadedDoc!)
          .limit(_historyPageSize)
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _olderMessages.addAll(snapshot.docs);
        _oldestLoadedDoc = snapshot.docs.isNotEmpty
            ? snapshot.docs.last
            : _oldestLoadedDoc;
        _hasMoreMessages = snapshot.docs.length == _historyPageSize;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _ensureChatRoomReady() async {
    if (_isPreparingRoom || _roomError != null) {
      await _primeChatRoom();
    }
    if (_roomError != null) {
      throw Exception(_roomError);
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _msgController.clear();
    await _addMessage(text: text, type: 'text');
  }

  Future<void> _addMessage({
    String? text,
    String? mediaUrl,
    required String type,
  }) async {
    await _ensureChatRoomReady();
    final roomRef = FirebaseFirestore.instance
        .collection('therapist_chats')
        .doc(_chatRoomId);
    await roomRef.set({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageType': type,
      'lastSenderId': _currentUserId,
    }, SetOptions(merge: true));

    await roomRef.collection('messages').add({
      'senderId': _currentUserId,
      'text': text,
      'mediaUrl': mediaUrl,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Share Image',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.headingDark,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _imageSourceTile(
                      Icons.camera_alt_rounded,
                      'Camera',
                      () {
                        Navigator.pop(ctx);
                        _pickAndSendImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _imageSourceTile(
                      Icons.photo_library_rounded,
                      'Gallery',
                      () {
                        Navigator.pop(ctx);
                        _pickAndSendImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageSourceTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.primaryFaint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile == null) {
      return;
    }

    setState(() => _isSending = true);
    try {
      await _ensureChatRoomReady();
      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance.ref(
        'therapist_chats/$_chatRoomId/$_currentUserId/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();

      await _addMessage(mediaUrl: url, type: 'image');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      _recordPulse.repeat(reverse: true);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) {
      return;
    }
    final path = await _audioRecorder.stop();
    _recordPulse.stop();
    setState(() {
      _isRecording = false;
      _isSending = true;
    });

    try {
      if (path != null) {
        await _ensureChatRoomReady();
        final file = File(path);
        final ref = FirebaseStorage.instance.ref(
          'therapist_chats/$_chatRoomId/$_currentUserId/${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        final uploadTask = await ref.putFile(file);
        final url = await uploadTask.ref.getDownloadURL();

        await _addMessage(mediaUrl: url, type: 'audio');
        if (await file.exists()) {
          await file.delete();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _playAudio(String url) async {
    if (_playingAudioUrl == url && _audioPlayer.state == PlayerState.playing) {
      await _audioPlayer.pause();
      setState(() => _playingAudioUrl = null);
      return;
    }

    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(url));
    if (!mounted) {
      return;
    }
    setState(() => _playingAudioUrl = url);
  }

  Future<void> _startAudioCall() async {
    await _startCall(audioOnly: true);
  }

  Future<void> _startVideoCall() async {
    await _startCall(audioOnly: false);
  }

  Future<void> _startCall({required bool audioOnly}) async {
    try {
      await _ensureChatRoomReady();
      if (!_canStartCalls) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Calls become available after a confirmed appointment.',
            ),
          ),
        );
        return;
      }

      final room = await _secureOperations.ensureCallRoom(
        counterpartId: widget.therapistId,
        audioOnly: audioOnly,
      );
      if (!mounted) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            roomId: room.roomId,
            therapistId: widget.therapistId,
            therapistName: widget.therapistName,
            audioOnly: audioOnly,
            initiatesCall: true,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _joinIncomingCall() async {
    final roomId = _activeCallRoomId;
    if (roomId == null || roomId.isEmpty) {
      return;
    }

    await _ensureChatRoomReady();
    if (!mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          roomId: roomId,
          therapistId: widget.therapistId,
          therapistName: widget.therapistName,
          audioOnly: _incomingCallAudioOnly,
          initiatesCall: false,
        ),
      ),
    );
  }

  Widget _buildRoomStatusBanner() {
    if (_isPreparingRoom) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: TherapistSurfaceCard(
          color: AppColors.primaryFaint,
          child: const Text(
            'Preparing secure chat…',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDeep,
            ),
          ),
        ),
      );
    }

    if (_roomError == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: TherapistSurfaceCard(
        color: TherapistColors.destructiveSurface,
        borderColor: AppColors.error.withValues(alpha: 0.18),
        child: Text(
          _roomError!,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFFB3261E),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingCallBanner() {
    if (!_hasIncomingCall || _activeCallRoomId == null) {
      return const SizedBox.shrink();
    }

    final callLabel = _incomingCallAudioOnly ? 'audio' : 'video';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: TherapistSurfaceCard(
        color: const Color(0xFFEAF4FF),
        borderColor: AppColors.primary.withValues(alpha: 0.14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryFaint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _incomingCallAudioOnly
                    ? Icons.call_rounded
                    : Icons.videocam_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Incoming $callLabel call',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Join $_displayName in the active secure call.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _joinIncomingCall,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Join',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          const AppBackground(),
          Column(
            children: [
              _buildRoomStatusBanner(),
              _buildIncomingCallBanner(),
              Expanded(child: _buildMessageList()),
              if (_isSending)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sending...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              _buildInputBar(),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: 0.94),
      elevation: 0,
      scrolledUnderElevation: 0.5,
      iconTheme: const IconThemeData(color: AppColors.primary),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryFaint,
            child: Text(
              _displayName[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName,
                style: const TextStyle(
                  color: AppColors.headingDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const Text(
                'Secure therapist chat',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      actions: [
        _buildAppBarAction(
          icon: Icons.call_rounded,
          tooltip: 'Audio Call',
          onTap: _isPreparingRoom ? null : _startAudioCall,
        ),
        _buildAppBarAction(
          icon: Icons.videocam_rounded,
          tooltip: 'Video Call',
          onTap: _isPreparingRoom ? null : _startVideoCall,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primaryFaint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: IconButton(
          icon: Icon(icon, size: 22),
          tooltip: tooltip,
          onPressed: onTap,
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    final docs = _messageDocs;
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.75;

    if (_roomError != null && docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TherapistEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Chat unavailable',
            message:
                'We could not prepare the secure conversation right now. Pull to retry by sending again in a moment.',
          ),
        ),
      );
    }

    if (_isInitialMessageLoad) {
      return ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 6,
        itemBuilder: (_, index) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: TherapistLoadingSkeleton(lines: 3),
        ),
      );
    }

    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TherapistEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No messages yet',
            message:
                'Start a secure conversation, share a photo, or hold the send button to record a voice note.',
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: docs.length + (_isLoadingHistory ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingHistory && index == docs.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final doc = docs[index];
        final payload = _TherapistChatMessagePayload.fromMap(doc.data());
        final isMe = payload.senderId == _currentUserId;
        return _TherapistChatMessageBubble(
          key: ValueKey(doc.id),
          payload: payload,
          isMe: isMe,
          maxBubbleWidth: maxBubbleWidth,
          isPlayingAudio: _playingAudioUrl == payload.mediaUrl,
          onPlayAudio: payload.type != 'audio' || payload.mediaUrl == null
              ? null
              : () => _playAudio(payload.mediaUrl!),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildInputIcon(
            Icons.add_rounded,
            onTap: _isPreparingRoom ? () {} : _showImageSourcePicker,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7FC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: TherapistColors.cardBorder),
              ),
              child: TextField(
                controller: _msgController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendTextMessage(),
                decoration: const InputDecoration(
                  hintText: 'Write a message or hold send to record...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onLongPress: _startRecording,
            onLongPressUp: _stopRecordingAndSend,
            onTap: _sendTextMessage,
            child: AnimatedBuilder(
              animation: _recordPulse,
              builder: (context, child) {
                return Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? Color.lerp(
                            AppColors.error,
                            AppColors.error.withValues(alpha: 0.6),
                            _recordPulse.value,
                          )
                        : AppColors.primary,
                    boxShadow: _isRecording
                        ? [
                            BoxShadow(
                              color: AppColors.error.withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : const [],
                  ),
                  child: Icon(
                    _isRecording ? Icons.mic_rounded : Icons.send_rounded,
                    color: Colors.white,
                    size: _isRecording ? 24 : 18,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputIcon(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primaryFaint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}

class _TherapistChatMessageBubble extends StatelessWidget {
  const _TherapistChatMessageBubble({
    super.key,
    required this.payload,
    required this.isMe,
    required this.maxBubbleWidth,
    required this.isPlayingAudio,
    required this.onPlayAudio,
  });

  final _TherapistChatMessagePayload payload;
  final bool isMe;
  final double maxBubbleWidth;
  final bool isPlayingAudio;
  final VoidCallback? onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final text = payload.text;
    final mediaUrl = payload.mediaUrl;
    final type = payload.type;
    final time = payload.timestamp;

    return RepaintBoundary(
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          margin: const EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(type == 'image' ? 4 : 12),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: (isMe ? AppColors.primary : Colors.black).withValues(
                  alpha: isMe ? 0.16 : 0.05,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (type == 'image' && mediaUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    mediaUrl,
                    width: maxBubbleWidth,
                    height: 200,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    cacheWidth: 1200,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) {
                        return child;
                      }
                      return Container(
                        height: 180,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          color: isMe ? Colors.white : AppColors.primary,
                        ),
                      );
                    },
                  ),
                ),
              if (type == 'audio' && mediaUrl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onPlayAudio,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.2)
                                : AppColors.primaryFaint,
                          ),
                          child: Icon(
                            isPlayingAudio
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: isMe ? Colors.white : AppColors.primary,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voice Message',
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            isPlayingAudio ? 'Playing...' : 'Tap to play',
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (type == 'text' && text != null && text.isNotEmpty)
                Text(
                  text,
                  style: TextStyle(
                    color: isMe ? Colors.white : AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              if (time != null)
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: type == 'image' ? 8 : 0,
                    right: type == 'image' ? 8 : 0,
                    bottom: type == 'image' ? 4 : 0,
                  ),
                  child: Text(
                    DateFormat('h:mm a').format(time),
                    style: TextStyle(
                      color: isMe ? Colors.white60 : AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapistChatMessagePayload {
  const _TherapistChatMessagePayload({
    required this.senderId,
    required this.text,
    required this.mediaUrl,
    required this.type,
    required this.timestamp,
  });

  final String? senderId;
  final String? text;
  final String? mediaUrl;
  final String type;
  final DateTime? timestamp;

  factory _TherapistChatMessagePayload.fromMap(Map<String, dynamic> data) {
    final mediaUrl =
        _coerceChatString(data['mediaUrl']) ??
        _coerceChatString(data['imageUrl']) ??
        _coerceChatString(data['audioUrl']) ??
        _coerceChatString(data['attachmentUrl']);
    final text =
        _coerceChatString(data['text']) ??
        _coerceChatString(data['message']) ??
        _coerceChatString(data['body']);

    return _TherapistChatMessagePayload(
      senderId:
          _coerceChatString(data['senderId']) ??
          _coerceChatString(data['sender']) ??
          _coerceChatString(data['authorId']),
      text: text,
      mediaUrl: mediaUrl,
      type: _resolveMessageType(data['type'], mediaUrl: mediaUrl, text: text),
      timestamp:
          _coerceChatDateTime(data['timestamp']) ??
          _coerceChatDateTime(data['createdAt']) ??
          _coerceChatDateTime(data['sentAt']),
    );
  }

  static String _resolveMessageType(
    dynamic rawType, {
    required String? mediaUrl,
    required String? text,
  }) {
    final normalized = _coerceChatString(rawType)?.toLowerCase();
    if (normalized == 'audio' ||
        normalized == 'image' ||
        normalized == 'text') {
      return normalized!;
    }
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      final lower = mediaUrl.toLowerCase();
      if (lower.endsWith('.m4a') ||
          lower.endsWith('.aac') ||
          lower.endsWith('.wav') ||
          lower.endsWith('.mp3') ||
          lower.contains('/audio/')) {
        return 'audio';
      }
      return 'image';
    }
    return text == null || text.isEmpty ? 'text' : 'text';
  }
}

String? _coerceChatString(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  return null;
}

DateTime? _coerceChatDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

bool _coerceChatBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  return false;
}

bool _hasSessionDescription(dynamic value) {
  if (value is! Map) {
    return false;
  }
  final sdp = _coerceChatString(value['sdp']);
  final type = _coerceChatString(value['type']);
  return sdp != null && type != null;
}
