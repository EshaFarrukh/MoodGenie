import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:moodgenie/src/theme/app_theme.dart';

class CircularScorePainter extends CustomPainter {
  final double score;
  final double maxScore;

  CircularScorePainter({
    required this.score,
    required this.maxScore,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle (light purple)
    final bgPaint = Paint()
      ..color = const Color(0xFFE5DEFF).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 10, bgPaint);

    // Progress circle (gradient effect with multiple layers)
    final progressAngle = (score / maxScore) * 2 * math.pi;

    // Outer glow
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withOpacity(0.6),
          AppColors.primaryDeep.withOpacity(0.6),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      -math.pi / 2,
      progressAngle,
      false,
      glowPaint,
    );

    // Main progress arc
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary,
          AppColors.primaryDeep,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      -math.pi / 2,
      progressAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularScorePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.maxScore != maxScore;
  }
}
