import 'package:flutter/material.dart';
import 'package:moodgenie/l10n/app_localizations.dart';
import 'package:moodgenie/src/theme/app_background.dart';
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background — same as the app
          const AppBackground(),

          // Semi-transparent overlay for better contrast
          Container(color: Colors.white.withValues(alpha: 0.3)),

          // Centered logo + tagline
          Semantics(
            label: l10n.splashLoadingLabel,
            liveRegion: true,
            child: Center(
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
                            AppColors.primary,
                            Color(0xFFB87FD8),
                            Color(0xFFD87FB8),
                            AppColors.accentCyan,
                            Color(0xFFFFB366),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        child: Text(
                          l10n.appTitle,
                          style: const TextStyle(
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
                        l10n.splashTagline,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.bodyMuted.withValues(alpha: 0.85),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Loading indicator
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                          strokeWidth: 2.5,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                        ),
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
}

/// Draws the curved underline beneath the logo
class _CurvedUnderlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          AppColors.primary,
          Color(0xFFB87FD8),
          Color(0xFFD87FB8),
          AppColors.accentCyan,
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
      size.width / 2,
      size.height,
      size.width,
      size.height / 2,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
