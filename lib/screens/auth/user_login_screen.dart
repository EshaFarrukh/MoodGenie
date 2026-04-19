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
// 1) assets/logo/moodgenielogo.png
// 3) assets/icons/google.svg

import 'dart:ui';
import 'package:moodgenie/src/theme/app_background.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:moodgenie/screens/auth/signup_screen.dart';
import 'package:moodgenie/src/theme/app_theme.dart';
import '../../src/auth/services/auth_service.dart';
import '../../src/auth/models/auth_models.dart';

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();

  bool _loading = false;
  bool _hidePass = true;
  String? _error;
  AuthService? _authService;

  @override
  void dispose() {
    _authService?.removeListener(_handleAuthStateChanged);
    _emailC.dispose();
    _passC.dispose();
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

  Future<void> _login() async {
    final email = _emailC.text.trim();
    final password = _passC.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    setState(() {
      _error = null;
    });

    await context.read<AuthService>().signIn(email: email, password: password);
  }

  void _handleAuthStateChanged() {
    final authState = _authService?.state;
    if (!mounted || authState == null) {
      return;
    }

    if (authState.status == AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
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

  Future<void> _openSignUp() async {
    final registrationSuccess = await Navigator.of(context)
        .push<RegistrationSuccess>(
          MaterialPageRoute(builder: (_) => const SignUpScreen()),
        );

    if (!mounted || registrationSuccess == null) {
      return;
    }

    setState(() {
      _emailC.text = registrationSuccess.email;
      _passC.clear();
      _error = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(registrationSuccess.message)));
  }

  Future<void> _resetPassword() async {
    final email = _emailC.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first to reset your password');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.message ?? 'Could not send reset email');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final w = mediaQuery.size.width;
    final cardWidth = w.clamp(0, 420).toDouble();
    final keyboardInset = mediaQuery.viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryDeep),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      extendBodyBehindAppBar: true,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const AppBackground(),

            Container(color: const Color(0xFFBCA6FF).withValues(alpha: 0.08)),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final minHeight = (constraints.maxHeight - keyboardInset)
                      .clamp(0.0, double.infinity)
                      .toDouble();

                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: keyboardInset),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            const SizedBox(height: 18),

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
                                      colors: [
                                        AppColors.primary,
                                        AppColors.accentCyan,
                                      ],
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

                            const SizedBox(height: 24),

                            // Title
                            const Text(
                              'Welcome to MoodGenie',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.headingDark,
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Log in to continue',
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
                                      onPressed: () => setState(
                                        () => _hidePass = !_hidePass,
                                      ),
                                      icon: Icon(
                                        _hidePass
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Forgot password
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _loading
                                          ? null
                                          : _resetPassword,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 0,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Forgot password?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Error message display
                                  if (_error != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.1,
                                        ),
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

                                  // Log in button (animated gradient glow)
                                  AnimatedContainer(
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
                                            alpha: _loading ? 0.1 : 0.35,
                                          ),
                                          blurRadius: _loading ? 10 : 25,
                                          offset: Offset(0, _loading ? 4 : 12),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: _loading ? null : _login,
                                        splashColor: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        highlightColor: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        child: Center(
                                          child: _loading
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2.5,
                                                      ),
                                                )
                                              : const Text(
                                                  'Log in',
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
                                        onTap: _openSignUp,
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

                            SizedBox(
                              width: cardWidth,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
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
                  );
                },
              ),
            ),
          ],
        ),
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
