import 'package:flutter/material.dart';
import '../../src/theme/app_theme.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final bool isTherapist;

  const VideoCallScreen({super.key, required this.roomId, required this.isTherapist});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isMicMuted = false;
  bool _isVideoMuted = false;

  @override
  void initState() {
    super.initState();
    initRenderers();
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    // TODO: Connect to STUN/TURN servers and Firestore signaling logic here
    // using the provided widget.roomId
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Session: ${widget.roomId}', style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Remote Video Stream (Full Screen Placeholder)
          Container(
            color: Colors.grey.shade900,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off, color: Colors.white54, size: 80),
                  SizedBox(height: 16),
                  Text('Waiting for connection...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
          
          // Local Video Stream (Picture in Picture Placeholder)
          Positioned(
            right: 20,
            bottom: 120,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white54, size: 40),
              ),
            ),
          ),
          
          // Call Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton(
                  icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                  color: _isMicMuted ? Colors.red : Colors.white24,
                  onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                ),
                const SizedBox(width: 20),
                _buildControlButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  size: 64,
                  iconSize: 32,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 20),
                _buildControlButton(
                  icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
                  color: _isVideoMuted ? Colors.red : Colors.white24,
                  onTap: () => setState(() => _isVideoMuted = !_isVideoMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required Color color, required VoidCallback onTap, double size = 56, double iconSize = 24}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
