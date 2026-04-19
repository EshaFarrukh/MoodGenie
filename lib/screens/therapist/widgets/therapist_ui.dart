import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/session_model.dart';
import '../../../src/theme/app_theme.dart';
import '../models/therapist_workspace_models.dart';

class TherapistSurfaceCard extends StatelessWidget {
  const TherapistSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TherapistSpacing.l),
    this.margin,
    this.color,
    this.borderColor,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? Colors.white.withValues(alpha: 0.94))
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(TherapistRadii.card),
        border: Border.all(color: borderColor ?? TherapistColors.cardBorder),
        boxShadow: AppShadows.card(color: AppColors.primary),
      ),
      child: child,
    );
  }
}

class TherapistResponsiveContainer extends StatelessWidget {
  const TherapistResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1120,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class PrimaryCard extends StatelessWidget {
  const PrimaryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TherapistSpacing.l),
    this.margin,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return TherapistSurfaceCard(
      margin: margin,
      padding: padding,
      color: color ?? TherapistColors.elevatedSurface,
      borderColor: borderColor ?? Colors.white.withValues(alpha: 0.88),
      child: child,
    );
  }
}

class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TherapistSpacing.l),
    this.margin,
    this.gradient,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return TherapistSurfaceCard(
      margin: margin,
      padding: padding,
      gradient:
          gradient ??
          const LinearGradient(
            colors: [
              TherapistColors.headerDeep,
              TherapistColors.headerTop,
              TherapistColors.headerAccent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
      borderColor: borderColor ?? TherapistColors.glassStroke,
      child: child,
    );
  }
}

class TherapistSummaryCard extends StatelessWidget {
  const TherapistSummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
    this.gradient,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return TherapistSurfaceCard(
      gradient:
          gradient ??
          const LinearGradient(
            colors: [TherapistColors.headerTop, TherapistColors.headerBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
      borderColor: Colors.white.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: TherapistSpacing.xs),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: TherapistSpacing.m),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: TherapistSpacing.l),
          child,
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return TherapistSectionHeader(
      title: title,
      subtitle: subtitle,
      icon: icon,
      action: action,
    );
  }
}

class TherapistSectionHeader extends StatelessWidget {
  const TherapistSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryFaint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primaryDeep),
          ),
        if (icon != null) const SizedBox(width: TherapistSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.headingDark,
                  letterSpacing: -0.4,
                ),
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: TherapistSpacing.xxs),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: TherapistSpacing.m),
          action!,
        ],
      ],
    );
  }
}

class DaySelector extends StatelessWidget {
  const DaySelector({
    super.key,
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final TherapistDayOverview day;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final baseText = isSelected ? Colors.white : AppColors.headingDark;
    final subText = isSelected
        ? Colors.white.withValues(alpha: 0.82)
        : AppColors.textSecondary;
    final label = day.totalCount == 1
        ? '1 session'
        : '${day.totalCount} sessions';
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: isSelected ? 1 : 0.975,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 78,
            padding: const EdgeInsets.symmetric(
              horizontal: TherapistSpacing.s,
              vertical: TherapistSpacing.s,
            ),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF2E83D7), TherapistColors.headerTop],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.22)
                    : TherapistColors.cardBorder,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryDeep.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('EEE').format(day.date),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.primaryDeep,
                  ),
                ),
                const SizedBox(height: TherapistSpacing.xs),
                Text(
                  DateFormat('d').format(day.date),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -1,
                    color: baseText,
                  ),
                ),
                const SizedBox(height: TherapistSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: subText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isToday) ...[
                  const SizedBox(height: TherapistSpacing.xxs),
                  Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : AppColors.primaryDeep.withValues(alpha: 0.84),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TherapistStatusBadge extends StatelessWidget {
  const TherapistStatusBadge({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  factory TherapistStatusBadge.appointment(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.requested:
        return const TherapistStatusBadge(
          label: 'Pending',
          foreground: TherapistColors.pending,
          background: TherapistColors.pendingSurface,
          icon: Icons.schedule_rounded,
        );
      case AppointmentStatus.confirmed:
        return const TherapistStatusBadge(
          label: 'Confirmed',
          foreground: AppColors.success,
          background: TherapistColors.confirmedSurface,
          icon: Icons.verified_rounded,
        );
      case AppointmentStatus.completed:
        return const TherapistStatusBadge(
          label: 'Completed',
          foreground: AppColors.primaryDeep,
          background: AppColors.primaryFaint,
          icon: Icons.check_circle_rounded,
        );
      case AppointmentStatus.cancelled:
        return const TherapistStatusBadge(
          label: 'Cancelled',
          foreground: AppColors.error,
          background: TherapistColors.destructiveSurface,
          icon: Icons.cancel_rounded,
        );
      case AppointmentStatus.rejected:
        return const TherapistStatusBadge(
          label: 'Rejected',
          foreground: AppColors.error,
          background: TherapistColors.destructiveSurface,
          icon: Icons.close_rounded,
        );
      case AppointmentStatus.noShow:
        return const TherapistStatusBadge(
          label: 'No show',
          foreground: AppColors.warning,
          background: Color(0xFFFFF7E8),
          icon: Icons.person_off_rounded,
        );
    }
  }

  factory TherapistStatusBadge.moodSummary(
    TherapistMoodInsightTone tone,
    String label,
  ) {
    switch (tone) {
      case TherapistMoodInsightTone.uplifting:
        return TherapistStatusBadge(
          label: label,
          foreground: AppColors.success,
          background: TherapistColors.confirmedSurface,
          icon: Icons.wb_sunny_rounded,
        );
      case TherapistMoodInsightTone.watchful:
        return TherapistStatusBadge(
          label: label,
          foreground: TherapistColors.pending,
          background: TherapistColors.pendingSurface,
          icon: Icons.monitor_heart_outlined,
        );
      case TherapistMoodInsightTone.privateData:
        return TherapistStatusBadge(
          label: label,
          foreground: AppColors.textSecondary,
          background: AppColors.surfaceWarm,
          icon: Icons.lock_outline_rounded,
        );
      case TherapistMoodInsightTone.neutral:
      case TherapistMoodInsightTone.steady:
        return TherapistStatusBadge(
          label: label,
          foreground: AppColors.primaryDeep,
          background: AppColors.primaryFaint,
          icon: Icons.favorite_border_rounded,
        );
    }
  }

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TherapistSpacing.s,
        vertical: TherapistSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TherapistRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: TherapistSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class TherapistInfoBanner extends StatelessWidget {
  const TherapistInfoBanner({
    super.key,
    required this.title,
    required this.icon,
    this.message,
    this.action,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final foreground = foregroundColor ?? AppColors.primaryDeep;
    return TherapistSurfaceCard(
      padding: const EdgeInsets.all(TherapistSpacing.m),
      color: backgroundColor ?? Colors.white.withValues(alpha: 0.82),
      borderColor: foreground.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: foreground, size: 20),
          ),
          const SizedBox(width: TherapistSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.headingDark,
                  ),
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  const SizedBox(height: TherapistSpacing.xxs),
                  Text(
                    message!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: TherapistSpacing.s),
            action!,
          ],
        ],
      ),
    );
  }
}

class TherapistEmptyState extends StatelessWidget {
  const TherapistEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.action,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return TherapistSurfaceCard(
        color: Colors.white.withValues(alpha: 0.76),
        borderColor: Colors.white.withValues(alpha: 0.9),
        padding: const EdgeInsets.all(TherapistSpacing.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryFaint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primaryDeep, size: 22),
            ),
            const SizedBox(width: TherapistSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.headingDark,
                    ),
                  ),
                  const SizedBox(height: TherapistSpacing.xxs),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.35,
                      fontSize: 12,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: TherapistSpacing.s),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return TherapistSurfaceCard(
      color: Colors.white.withValues(alpha: 0.72),
      borderColor: Colors.white.withValues(alpha: 0.9),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryFaint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: AppColors.primaryDeep, size: 30),
          ),
          const SizedBox(height: TherapistSpacing.m),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.headingDark,
            ),
          ),
          const SizedBox(height: TherapistSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: TherapistSpacing.m),
            action!,
          ],
        ],
      ),
    );
  }
}

class TherapistSearchBar extends StatelessWidget {
  const TherapistSearchBar({
    super.key,
    required this.onChanged,
    required this.hintText,
    this.trailing,
    this.controller,
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final Widget? trailing;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TherapistSurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: TherapistSpacing.m,
        vertical: TherapistSpacing.xs,
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.primary),
          const SizedBox(width: TherapistSpacing.s),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: const TextStyle(color: AppColors.captionLight),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: TherapistSpacing.s),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class TherapistLoadingSkeleton extends StatelessWidget {
  const TherapistLoadingSkeleton({
    super.key,
    this.lines = 3,
    this.showAvatar = false,
  });

  final int lines;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 0.85),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return TherapistSurfaceCard(
          color: Colors.white.withValues(alpha: 0.92),
          child: Opacity(
            opacity: value,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAvatar) ...[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  const SizedBox(width: TherapistSpacing.m),
                ],
                Expanded(
                  child: Column(
                    children: List.generate(lines, (index) {
                      return Container(
                        margin: EdgeInsets.only(
                          bottom: index == lines - 1 ? 0 : TherapistSpacing.s,
                        ),
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    this.detail,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return StatCard(
      value: value,
      label: label,
      detail: detail,
      icon: icon,
      accent: accent,
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    this.detail,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final hasDetail = detail != null && detail!.trim().isNotEmpty;
    return PrimaryCard(
      padding: const EdgeInsets.symmetric(
        horizontal: TherapistSpacing.s,
        vertical: TherapistSpacing.m,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.14)),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: TherapistSpacing.s),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.headingDark,
              letterSpacing: -1.1,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: TherapistSpacing.xxs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.bodyMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (hasDetail) ...[
            const SizedBox(height: TherapistSpacing.xs),
            Text(
              detail!,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class PatientListItem extends StatelessWidget {
  const PatientListItem({
    super.key,
    required this.summary,
    this.onTap,
    this.onMessage,
    this.compact = false,
  });

  final TherapistPatientSummary summary;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;
  final bool compact;

  String _lastInteractionLabel() {
    final date = summary.lastInteractionAt;
    if (date == null) {
      return 'No recent session activity';
    }
    return 'Last interaction ${DateFormat('MMM d').format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final displaySource = summary.user.name?.trim().isNotEmpty == true
        ? summary.user.name!.trim()
        : summary.user.email;
    if (compact) {
      return TherapistSurfaceCard(
        margin: const EdgeInsets.only(bottom: TherapistSpacing.s),
        padding: const EdgeInsets.all(TherapistSpacing.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(TherapistRadii.card),
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTight = constraints.maxWidth < 320;
              final messageAction = onMessage == null
                  ? null
                  : TextButton(
                      onPressed: onMessage,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TherapistSpacing.s,
                          vertical: TherapistSpacing.xs,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Message'),
                    );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryFaint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        displaySource.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primaryDeep,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: TherapistSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isTight) ...[
                          Text(
                            summary.user.name ?? 'Patient',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.headingDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: TherapistSpacing.xxs),
                          TherapistStatusBadge.moodSummary(
                            summary.moodTone,
                            summary.moodSummaryLabel,
                          ),
                          const SizedBox(height: TherapistSpacing.xs),
                          Text(
                            _lastInteractionLabel(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (messageAction != null) ...[
                            const SizedBox(height: TherapistSpacing.xs),
                            messageAction,
                          ],
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  summary.user.name ?? 'Patient',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.headingDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: TherapistSpacing.s),
                              Flexible(
                                child: TherapistStatusBadge.moodSummary(
                                  summary.moodTone,
                                  summary.moodSummaryLabel,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: TherapistSpacing.xxs),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _lastInteractionLabel(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (messageAction != null) ...[
                                const SizedBox(width: TherapistSpacing.s),
                                messageAction,
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }
    return TherapistSurfaceCard(
      margin: const EdgeInsets.only(bottom: TherapistSpacing.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(TherapistRadii.card),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryFaint, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  displaySource.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primaryDeep,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: TherapistSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.user.name ?? 'Patient',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.headingDark,
                              ),
                            ),
                            const SizedBox(height: TherapistSpacing.xxs),
                            Text(
                              summary.user.email,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TherapistStatusBadge.moodSummary(
                        summary.moodTone,
                        summary.moodSummaryLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: TherapistSpacing.s),
                  Text(
                    summary.moodSummaryDetail,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.bodyMuted,
                    ),
                  ),
                  const SizedBox(height: TherapistSpacing.s),
                  Wrap(
                    spacing: TherapistSpacing.s,
                    runSpacing: TherapistSpacing.s,
                    children: [
                      TherapistStatusBadge(
                        label: summary.relationshipLabel,
                        foreground: AppColors.primaryDeep,
                        background: AppColors.primaryFaint,
                        icon: Icons.people_alt_rounded,
                      ),
                      if (summary.latestStatus != null)
                        TherapistStatusBadge.appointment(summary.latestStatus!),
                    ],
                  ),
                  const SizedBox(height: TherapistSpacing.s),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: TherapistSpacing.xs),
                      Expanded(
                        child: Text(
                          _lastInteractionLabel(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (onMessage != null)
                        TextButton.icon(
                          onPressed: onMessage,
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Message'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.item,
    this.onTap,
    this.secondaryAction,
    this.highlightColor,
    this.compact = false,
  });

  final TherapistScheduleItem item;
  final VoidCallback? onTap;
  final Widget? secondaryAction;
  final Color? highlightColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent =
        highlightColor ??
        (item.isPending
            ? TherapistColors.pending
            : item.isConfirmed
            ? AppColors.primary
            : AppColors.textSecondary);
    if (compact) {
      return TherapistSurfaceCard(
        margin: const EdgeInsets.only(bottom: TherapistSpacing.s),
        borderColor: accent.withValues(alpha: 0.14),
        padding: const EdgeInsets.all(TherapistSpacing.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(TherapistRadii.card),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(
                  horizontal: TherapistSpacing.xs,
                  vertical: TherapistSpacing.s,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('h:mm').format(item.startsAt),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.headingDark,
                      ),
                    ),
                    Text(
                      DateFormat('a').format(item.startsAt),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TherapistSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.patientName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.headingDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: TherapistSpacing.s),
                        TherapistStatusBadge.appointment(item.status),
                      ],
                    ),
                    const SizedBox(height: TherapistSpacing.xxs),
                    Text(
                      DateFormat('EEE, MMM d').format(item.startsAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TherapistSpacing.s),
              secondaryAction ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primaryDeep.withValues(alpha: 0.7),
                  ),
            ],
          ),
        ),
      );
    }
    return TherapistSurfaceCard(
      margin: const EdgeInsets.only(bottom: TherapistSpacing.m),
      borderColor: accent.withValues(alpha: 0.18),
      child: InkWell(
        borderRadius: BorderRadius.circular(TherapistRadii.card),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              padding: const EdgeInsets.symmetric(
                horizontal: TherapistSpacing.s,
                vertical: TherapistSpacing.s,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('h:mm').format(item.startsAt),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.headingDark,
                    ),
                  ),
                  Text(
                    DateFormat('a').format(item.startsAt),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TherapistSpacing.m),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 240;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isNarrow) ...[
                        Text(
                          item.patientName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.headingDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: TherapistSpacing.xs),
                        TherapistStatusBadge.appointment(item.status),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.patientName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.headingDark,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: TherapistSpacing.s),
                            TherapistStatusBadge.appointment(item.status),
                          ],
                        ),
                      const SizedBox(height: TherapistSpacing.xs),
                      Text(
                        item.patientEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: TherapistSpacing.s),
                      Wrap(
                        spacing: TherapistSpacing.s,
                        runSpacing: TherapistSpacing.xs,
                        children: [
                          _infoPill(
                            icon: Icons.calendar_month_rounded,
                            text: DateFormat(
                              'EEE, MMM d',
                            ).format(item.startsAt),
                          ),
                          _infoPill(
                            icon: Icons.video_call_rounded,
                            text: item.isPending
                                ? 'Review request'
                                : 'Secure session',
                          ),
                          if (item.session.timezone != null &&
                              item.session.timezone!.trim().isNotEmpty)
                            _infoPill(
                              icon: Icons.public_rounded,
                              text: item.session.timezone!,
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            if (secondaryAction != null) ...[
              const SizedBox(width: TherapistSpacing.m),
              secondaryAction!,
            ] else
              const Padding(
                padding: EdgeInsets.only(left: TherapistSpacing.m),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TherapistSpacing.s,
        vertical: TherapistSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: TherapistColors.inset,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primaryDeep),
          const SizedBox(width: TherapistSpacing.xs),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class TherapistActionButtonSet extends StatelessWidget {
  const TherapistActionButtonSet({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TherapistSpacing.s,
      runSpacing: TherapistSpacing.s,
      children: children,
    );
  }
}

class TherapistReasonDialog {
  const TherapistReasonDialog._();

  static Future<String?> prompt(
    BuildContext context, {
    required String title,
    required String hintText,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TherapistRadii.dialog),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.headingDark,
            ),
          ),
          content: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 6,
            autofocus: true,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: TherapistColors.workspaceTint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: TherapistColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: TherapistColors.cardBorder),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(trimmed);
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }
}
