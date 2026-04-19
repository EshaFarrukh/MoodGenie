import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:moodgenie/src/theme/app_theme.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE0F2FE), // Very light blue
                Color(0xFFF0F9FF), // Sky blue
                Color(0xFFD6EAF8), // Slightly deeper
              ],
            ),
          ),
        ),
        // Top Left Orb
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentCyan.withValues(alpha: 0.4),
            ),
          ),
        ),
        // Bottom Right Orb
        Positioned(
          bottom: -150,
          right: -50,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight.withValues(alpha: 0.3),
            ),
          ),
        ),
        // Center Right Subtle Glow
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          right: -150,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryDeep.withValues(alpha: 0.15),
            ),
          ),
        ),
        // Heavy Blur to seamlessly merge them into a mesh
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}
