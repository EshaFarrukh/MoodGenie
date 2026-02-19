import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/auth_models.dart';

class RoleGate extends StatelessWidget {
  final Widget userHome;
  final Widget therapistDashboard;
  final Widget loginScreen;
  final Widget splashScreen;

  const RoleGate({
    super.key,
    required this.userHome,
    required this.therapistDashboard,
    required this.loginScreen,
    required this.splashScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final state = authService.state;

        switch (state.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return splashScreen;

          case AuthStatus.authenticated:
            final user = authService.currentUser;
            if (user == null) return splashScreen;

            switch (user.role) {
              case UserRole.therapist:
                return therapistDashboard;
              case UserRole.user:
              case UserRole.admin:
              default:
                return userHome;
            }

          case AuthStatus.unauthenticated:
            return loginScreen;
        }
      },
    );
  }
}

class AuthBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, AuthState state, AppUser? user) builder;

  const AuthBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return builder(context, authService.state, authService.currentUser);
      },
    );
  }
}

class AuthLoadingOverlay extends StatelessWidget {
  final Widget child;
  final String? loadingMessage;

  const AuthLoadingOverlay({
    super.key,
    required this.child,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return Stack(
          children: [
            child,
            if (authService.isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      if (loadingMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          loadingMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
