import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../src/theme/app_theme.dart';

/// Unified glass-morphism card used app-wide.
///
/// Two styles:
///  • **Gradient** — provide [gradientColors] for a soft colored glass card.
///  • **Translucent** — omit [gradientColors] for a frosted-glass card overlay.
class GlassCard extends StatelessWidget {
  final List<Color>? gradientColors;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const GlassCard({
    super.key,
    this.gradientColors,
    this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isTranslucent = gradientColors == null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.l),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: isTranslucent ? 16 : 10, sigmaY: isTranslucent ? 16 : 10),
        child: Container(
          margin: isTranslucent ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 4),
          padding: padding ?? const EdgeInsets.all(18),
          width: isTranslucent ? double.infinity : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.l),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isTranslucent
                  ? [
                      const Color(0xFFFFFFFF).withOpacity(0.25),
                      const Color(0xFFE8DAFF).withOpacity(0.20),
                    ]
                  : [
                      gradientColors![0].withOpacity(0.90),
                      gradientColors![1].withOpacity(0.82),
                    ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(isTranslucent ? 0.6 : 0.35),
              width: isTranslucent ? 1.5 : 1,
            ),
            boxShadow: isTranslucent
                ? AppShadows.card()
                : AppShadows.soft(),
          ),
          child: child,
        ),
      ),
    );
  }
}
