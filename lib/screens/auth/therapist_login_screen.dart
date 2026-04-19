import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moodgenie/src/theme/app_background.dart';
import 'package:moodgenie/src/theme/app_theme.dart';
import 'package:moodgenie/screens/auth/therapist_signup_screen.dart';
import '../../src/auth/services/auth_service.dart';
import '../../src/auth/models/auth_models.dart';
import '../../src/auth/widgets/auth_widgets.dart';

class TherapistLoginScreen extends StatefulWidget {
  const TherapistLoginScreen({super.key});

  @override
  State<TherapistLoginScreen> createState() => _TherapistLoginScreenState();
}

class _TherapistLoginScreenState extends State<TherapistLoginScreen> {
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

  Future<void> _openTherapistSignUp() async {
    final registrationSuccess = await Navigator.of(context)
        .push<RegistrationSuccess>(
          MaterialPageRoute(builder: (_) => const TherapistSignUpScreen()),
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
            Container(color: AppColors.primaryLight.withValues(alpha: 0.1)),
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
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan.withValues(
                                  alpha: 0.15,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.medical_services,
                                  size: 40,
                                  color: AppColors.primaryDeep,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Therapist Portal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.headingDark,
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Log in to your practice dashboard',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 32),

                            _GlassPanel(
                              width: cardWidth,
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _emailC,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Email address',
                                      hintStyle: TextStyle(
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.6),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        color: AppColors.textSecondary,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _passC,
                                    obscureText: _hidePass,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _login(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Password',
                                      hintStyle: TextStyle(
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.6),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                        color: AppColors.textSecondary,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _hidePass
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: AppColors.textSecondary,
                                        ),
                                        onPressed: () => setState(
                                          () => _hidePass = !_hidePass,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _loading
                                          ? null
                                          : _resetPassword,
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const SizedBox(height: 24),
                                  // Log in button (animated gradient glow)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: double.infinity,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
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
                                        borderRadius: BorderRadius.circular(16),
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
                                                  'Log In as Therapist',
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
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "Don't have an account? ",
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _openTherapistSignUp,
                                        child: const Text(
                                          'Join Network',
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

                            // Error Display
                            AuthBuilder(
                              builder: (context, state, user) {
                                if (state.error != null || _error != null) {
                                  final errorMessage = state.error ?? _error!;
                                  return Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    padding: const EdgeInsets.all(12),
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
                                        const Icon(
                                          Icons.error_outline,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            errorMessage,
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
