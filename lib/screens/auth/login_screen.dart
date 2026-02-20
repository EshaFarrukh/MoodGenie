// lib/screens/auth/login_screen.dart
//
// ✅ Exact-style Login screen matching SignUp design
// - Same dreamy background image
// - Center logo + title + subtitle
// - Glass card with 2 fields (email/password)
// - Peach gradient "Log in" button
// - "Don't have an account? Sign up"
// - Divider "or"
// - Google button with SVG icon
//
// 🔧 Assets required:
// 1) assets/images/login_bg.png
// 2) assets/logo/moodgenielogo.png
// 3) assets/icons/google.svg

import 'dart:ui';
import 'package:moodgenie/src/theme/app_background.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:moodgenie/screens/auth/signup_screen.dart';
import 'package:moodgenie/screens/auth/therapist_signup_screen.dart';
import '../../src/auth/services/auth_service.dart';
import '../../src/auth/widgets/auth_widgets.dart';
import 'package:moodgenie/screens/auth/signup_screen.dart';
import 'package:moodgenie/screens/auth/therapist_signup_screen.dart';
import 'package:moodgenie/src/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();

  bool _loading = false;
  bool _hidePass = true;
  String? _error;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailC.text.trim();
    final password = _passC.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    final authService = context.read<AuthService>();
    await authService.signIn(email: email, password: password);

    if (mounted && authService.state.error != null) {
      setState(() => _error = authService.state.error);
    }
  }


  @override
  Widget build(BuildContext context) {
    // For consistent sizing across devices
    final w = MediaQuery.of(context).size.width;
    final cardWidth = w.clamp(0, 420).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background image (full screen)
          Positioned.fill(
            child: const AppBackground(),
          ),

          // Soft overlay tint to match screenshot glow
          Positioned.fill(
            child: Container(
              color: const Color(0xFFBCA6FF).withOpacity(0.08),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
              child: Column(
                children: [
                  const SizedBox(height: 18),

                  // Logo - Directly on background
                  Container(
                    width: 100,
                    height: 100,
                    child: Center(
                      child: Image.asset(
                        'assets/logo/moodgenielogo.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to M text if image fails to load
                          return Text(
                            'M',
                            style: TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF8A5C),
                              letterSpacing: -2,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Title
                  const Text(
                    'Welcome to MoodGenie',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6A5F88),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Log in to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8B81A6),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Glass card
                  _GlassPanel(
                    width: cardWidth,
                    child: Column(
                      children: [
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
                          hint: 'Enter your password',
                          controller: _passC,
                          obscureText: _hidePass,
                          textInputAction: TextInputAction.done,
                          suffix: IconButton(
                            onPressed: () => setState(() => _hidePass = !_hidePass),
                            icon: Icon(
                              _hidePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF9B93B5),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8B81A6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        // Error message display
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
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
                                    _error!,
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
                          const SizedBox(height: 4),
                        ],

                        const SizedBox(height: 10),

                        // Log in button (peach gradient)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFFFFB06A),
                                  Color(0xFFFF7F72),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF8A5C).withOpacity(0.28),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: _loading ? null : _login,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Log in',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Don't have account? Sign up
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: Color(0xFF8B81A6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Sign up',
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

                  // Divider OR
                  SizedBox(
                    width: cardWidth,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.55),
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
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Google button (with SVG)
                  SizedBox(
                    width: cardWidth,
                    height: 52,
                    child: _GlassButton(
                      onTap: () {
                        // TODO: Google sign-in
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
                              color: Color(0xFF6A5F88),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Therapist Signup Option
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9966).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF9966).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9966),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.psychology_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Are you a therapist?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2D2545),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Join our professional network',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6D6689),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TherapistSignUpScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFF9966)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Sign Up as Therapist',
                              style: TextStyle(
                                color: Color(0xFFFF9966),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error Display
                  AuthBuilder(
                    builder: (context, state, user) {
                      if (state.error != null) {
                        return Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
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
            Colors.white.withOpacity(0.32),
            Colors.white.withOpacity(0.18),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withOpacity(0.22),
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.50),
                ),
              ),
              child: Center(child: child),
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
        color: Colors.white.withOpacity(0.26),
        border: Border.all(
          color: Colors.white.withOpacity(0.45),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.18),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF9B93B5),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              obscureText: obscureText,
              style: const TextStyle(
                color: Color(0xFF6A5F88),
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFFB3AACB),
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
