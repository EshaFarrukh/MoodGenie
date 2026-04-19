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

    return Container(
      margin: isTranslucent
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 4),
      padding: padding ?? const EdgeInsets.all(18),
      width: isTranslucent ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.l),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isTranslucent
              ? [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.88),
                ]
              : [
                  gradientColors![0].withValues(alpha: 0.90),
                  gradientColors![1].withValues(alpha: 0.82),
                ],
        ),
        boxShadow: isTranslucent
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: gradientColors![0].withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}
