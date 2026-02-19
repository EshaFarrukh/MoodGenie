import 'package:flutter/material.dart';
import '../../src/theme/app_theme.dart';

/// Splash screen with animated MoodGenie gradient logo
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background — same as the app
          Image.asset(
            'assets/images/moodgenie_bg.png',
            fit: BoxFit.cover,
          ),

          // Semi-transparent overlay for better contrast
          Container(
            color: Colors.white.withOpacity(0.3),
          ),

          // Centered logo + tagline
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // MoodGenie gradient text logo
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          AppColors.purple,
                          Color(0xFFB87FD8),
                          Color(0xFFD87FB8),
                          AppColors.accentOrange,
                          Color(0xFFFFB366),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      child: const Text(
                        'MoodGenie',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Curved underline decoration
                    CustomPaint(
                      size: const Size(280, 24),
                      painter: _CurvedUnderlinePainter(),
                    ),
                    const SizedBox(height: 20),
                    // Tagline
                    Text(
                      'Your AI Mental Wellness Companion',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bodyMuted.withOpacity(0.85),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Loading indicator
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AppColors.purple),
                        strokeWidth: 2.5,
                        backgroundColor: AppColors.purple.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the curved underline beneath the logo
class _CurvedUnderlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          AppColors.purple,
          Color(0xFFB87FD8),
          Color(0xFFD87FB8),
          AppColors.accentOrange,
          Color(0xFFFFB366),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height / 2);
    path.quadraticBezierTo(
      size.width / 2, size.height,
      size.width, size.height / 2,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
