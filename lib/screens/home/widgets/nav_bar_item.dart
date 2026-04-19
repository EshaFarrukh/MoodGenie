import 'package:flutter/material.dart';
import '../../../src/theme/app_theme.dart';

class NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final String semanticHint;
  final bool isSelected;
  final VoidCallback onTap;

  const NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.semanticHint,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      hint: semanticHint,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.m),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
              child: ExcludeSemantics(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentSoft.withValues(alpha: 0.13)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: isSelected
                            ? AppColors.accentSoft
                            : AppColors.navUnselected,
                        size: 23,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.accentSoft
                              : AppColors.navUnselected,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
