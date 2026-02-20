import 'package:flutter/material.dart';
import '../../src/theme/app_theme.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:math';
import 'dart:ui';

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
      backgroundColor: AppColors.headingDark,
      body: Stack(
        children: [
          // Simulated Remote Video Stream (Blurred modern backdrop)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryDeep, Color(0xFF001F3F)],
                ),
              ),
              child: Stack(
                children: [
                   Center(
                    child: Opacity(
                      opacity: 0.1,
                      child: Icon(Icons.monitor_heart_outlined, size: 250, color: Colors.white),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.accentBright, strokeWidth: 3),
                        const SizedBox(height: 24),
                        Text(
                          widget.isTherapist ? 'Waiting for Patient to connect...' : 'Connecting to Therapist...',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Secure WebRTC End-to-End Encryption',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Custom Sleek AppBar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.redAccent, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 12),
                        SizedBox(width: 6),
                        Text('LIVE', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text('Session ID: ${widget.roomId.substring(0, min(8, widget.roomId.length))}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ],
              ),
            ),
          ),
          
          // Local Video Stream (Picture in Picture Placeholder with Glassmorphism)
          Positioned(
            right: 20,
            bottom: 140,
            child: Container(
              width: 110,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: Icon(widget.isTherapist ? Icons.medical_services : Icons.person, color: Colors.white.withOpacity(0.8), size: 40),
                  ),
                ),
              ),
            ),
          ),
          
          // Premium Call Controls (Glassmorphism dock)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                        color: _isMicMuted ? Colors.redAccent : Colors.white.withOpacity(0.2),
                        onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                      ),
                      _buildControlButton(
                        icon: Icons.call_end,
                        color: Colors.redAccent,
                        size: 64,
                        iconSize: 32,
                        onTap: () => Navigator.pop(context),
                      ),
                      _buildControlButton(
                        icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
                        color: _isVideoMuted ? Colors.redAccent : Colors.white.withOpacity(0.2),
                        onTap: () => setState(() => _isVideoMuted = !_isVideoMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required Color color, required VoidCallback onTap, double size = 52, double iconSize = 24}) {
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
