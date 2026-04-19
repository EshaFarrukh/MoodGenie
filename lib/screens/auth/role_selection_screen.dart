import 'dart:ui';
import 'package:flutter/material.dart';
import '../../src/theme/app_theme.dart';
import 'package:moodgenie/src/theme/app_background.dart';
import 'user_login_screen.dart';
import 'therapist_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: AppBackground()),
          Positioned.fill(
            child: Container(
              color: const Color(0xFFBCA6FF).withValues(alpha: 0.08),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  // Logo/Header
                  Center(
                    child: SizedBox(
                      width: 130,
                      height: 130,
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, AppColors.accentCyan],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcIn,
                        child: Image.asset(
                          'assets/logo/moodgenielogo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text(
                              'M',
                              style: TextStyle(
                                fontSize: 70,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: -2,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to MoodGenie',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.headingDark,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your account type to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Role Options
                  _GlassRoleCard(
                    title: 'Student / Developer',
                    subtitle:
                        'Enhance your mood, browse resources, and find a professional to talk to.',
                    icon: Icons.school_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserLoginScreen(),
                        ),
                      );
                    },
                    isPrimary: true,
                  ),

                  const SizedBox(height: 20),

                  _GlassRoleCard(
                    title: 'Therapist',
                    subtitle:
                        'Manage clients, schedule telehealth sessions, and grow your practice.',
                    icon: Icons.psychology_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TherapistLoginScreen(),
                        ),
                      );
                    },
                    isPrimary: false,
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassRoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _GlassRoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPrimary
              ? [
                  Colors.white.withValues(alpha: 0.6),
                  Colors.white.withValues(alpha: 0.2),
                ]
              : [
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.1),
                ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isPrimary ? 0.9 : 0.4),
          width: isPrimary ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPrimary ? AppColors.primaryDeep : Colors.black)
                .withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              highlightColor: Colors.white.withValues(alpha: 0.1),
              splashColor: Colors.white.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? AppColors.accentCyan.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPrimary
                              ? AppColors.accentCyan.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 32,
                        color: isPrimary
                            ? AppColors.primary
                            : AppColors.primaryDeep,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: isPrimary
                                  ? AppColors.primaryDeep
                                  : AppColors.primaryDeep.withValues(
                                      alpha: 0.8,
                                    ),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: isPrimary
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
