// lib/screens/auth/signup_screen.dart
//
// ✅ Exact-style Signup screen like your screenshot
// - Uses SAME dreamy background image
// - Center logo + title + subtitle
// - Glass card with 4 fields (name/email/password/confirm)
// - Peach gradient "Sign up" button
// - "Already have an account? Log in"
// - Divider "or"
// - Google button with SVG icon
//
// 🔧 Assets you must have:
// 1) assets/logo/moodgenielogo.png  (your M logo PNG)
// 3) assets/icons/google.svg
//
// 🔧 pubspec.yaml
// flutter:
//   assets:
//     - assets/images/
//     - assets/icons/
//
// dependencies:
//   flutter_svg: ^2.0.10

import 'dart:ui';
import 'package:moodgenie/src/theme/app_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../src/auth/services/auth_service.dart';
import '../../src/auth/widgets/auth_widgets.dart';
import 'package:moodgenie/src/theme/app_theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.onLoginTap});

  final VoidCallback? onLoginTap;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();

  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _loading = false;
  String? _error;
  AuthService? _authService;

  @override
  void dispose() {
    _authService?.removeListener(_handleAuthStateChanged);
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authService = context.read<AuthService>();
    if (_authService == authService) {
      return;
    }

    _authService?.removeListener(_handleAuthStateChanged);
    _authService = authService;
    _authService?.addListener(_handleAuthStateChanged);
    _handleAuthStateChanged();
  }

  Future<void> _signUp() async {
    final name = _nameC.text.trim();
    final email = _emailC.text.trim();
    final password = _passC.text.trim();
    final confirmPassword = _confirmC.text.trim();

    // Basic validation
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() => _error = null);

    final registrationSuccess = await context.read<AuthService>().signUpUser(
      email: email,
      password: password,
      name: name,
    );

    if (!mounted || registrationSuccess == null) {
      return;
    }

    Navigator.of(context).pop(registrationSuccess);
  }

  void _handleAuthStateChanged() {
    final authState = _authService?.state;
    if (!mounted || authState == null) {
      return;
    }

    if (_loading == authState.isLoading && _error == authState.error) {
      return;
    }

    setState(() {
      _loading = authState.isLoading;
      _error = authState.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    // For consistent sizing across devices
    final w = MediaQuery.of(context).size.width;
    final cardWidth = w.clamp(0, 420).toDouble();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background image (full screen)
          Positioned.fill(child: const AppBackground()),

          // Soft overlay tint to match screenshot glow
          Positioned.fill(
            child: Container(
              color: const Color(0xFFBCA6FF).withValues(alpha: 0.08),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
              child: Column(
                children: [
                  const SizedBox(height: 18),

                  // Back Button if navigable
                  if (Navigator.canPop(context))
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),

                  // Logo - Directly on background
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Center(
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
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to M text if image fails to load
                            return const Text(
                              'M',
                              style: TextStyle(
                                fontSize: 60,
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

                  const SizedBox(height: 18),

                  // Title
                  const Text(
                    'Student / Developer Sign Up',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: AppColors.headingDark,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create an account to track your mood',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Glass card
                  _GlassPanel(
                    width: cardWidth,
                    child: Column(
                      children: [
                        _InputRow(
                          icon: Icons.person_outline_rounded,
                          hint: 'Enter your name',
                          controller: _nameC,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        _InputRow(
                          icon: Icons.mail_outline_rounded,
                          hint: 'Enter your email',
                          controller: _emailC,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        _InputRow(
                          icon: Icons.lock_outline_rounded,
                          hint: 'Create a password',
                          controller: _passC,
                          obscureText: _hidePass,
                          textInputAction: TextInputAction.next,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _hidePass = !_hidePass),
                            icon: Icon(
                              _hidePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF9B93B5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InputRow(
                          icon: Icons.lock_outline_rounded,
                          hint: 'Confirm your password',
                          controller: _confirmC,
                          obscureText: _hideConfirm,
                          textInputAction: TextInputAction.done,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _hideConfirm = !_hideConfirm),
                            icon: Icon(
                              _hideConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF9B93B5),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Error message display
                        AuthBuilder(
                          builder: (context, state, user) {
                            if (state.error != null || _error != null) {
                              final errorMessage = state.error ?? _error!;
                              return Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Colors.red.shade700,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            errorMessage,
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        // Sign up button (animated gradient glow)
                        AuthBuilder(
                          builder: (context, state, user) {
                            final isLoading = state.isLoading || _loading;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppColors.primary,
                                    AppColors.accentCyan,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: isLoading ? 0.1 : 0.35,
                                    ),
                                    blurRadius: isLoading ? 10 : 25,
                                    offset: Offset(0, isLoading ? 4 : 12),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: isLoading ? null : _signUp,
                                  splashColor: Colors.white.withValues(
                                    alpha: 0.2,
                                  ),
                                  highlightColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Center(
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Text(
                                            'Sign up',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        // Already have account? Log in
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: Color(0xFF8B81A6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (widget.onLoginTap != null) {
                                  widget.onLoginTap!();
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const Text(
                                'Log in',
                                style: TextStyle(
                                  color: AppColors.primaryDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: cardWidth,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: Color(0xFF8B81A6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: cardWidth,
                    height: 52,
                    child: _GlassButton(
                      onTap: _loading
                          ? null
                          : () async {
                              setState(() => _error = null);
                              await context
                                  .read<AuthService>()
                                  .signInWithGoogle();
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/google.svg',
                            height: 22,
                            width: 22,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(
                              color: AppColors.headingDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Glass container (blur + border + light gradient)
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: child,
        ),
      ),
    );
  }
}

/// Glass button used for Google
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withValues(alpha: isEnabled ? 0.22 : 0.16),
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: isEnabled ? 0.50 : 0.35,
                  ),
                ),
              ),
              child: Opacity(
                opacity: isEnabled ? 1 : 0.65,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Input row styled like screenshot (icon in pill, then textfield)
class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.icon,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
  });

  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.18),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              obscureText: obscureText,
              style: const TextStyle(
                color: AppColors.headingDark,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 4),
            suffix!,
            const SizedBox(width: 6),
          ] else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}
