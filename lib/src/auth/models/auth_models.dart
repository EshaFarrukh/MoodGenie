abstract class AuthFailure {
  final String message;
  const AuthFailure(this.message);
}

class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure() : super('This email address is already in use.');
}

class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure() : super('The password provided is too weak.');
}

class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure() : super('No user found for that email.');
}

class WrongPasswordFailure extends AuthFailure {
  const WrongPasswordFailure() : super('Wrong password provided for that user.');
}

class InvalidEmailFailure extends AuthFailure {
  const InvalidEmailFailure() : super('The email address is not valid.');
}

class UserDisabledFailure extends AuthFailure {
  const UserDisabledFailure() : super('This user account has been disabled.');
}

class NetworkFailure extends AuthFailure {
  const NetworkFailure() : super('Network error occurred. Please check your internet connection.');
}

class ServerFailure extends AuthFailure {
  const ServerFailure() : super('Server error occurred. Please try again later.');
}

class UnknownFailure extends AuthFailure {
  const UnknownFailure(String message) : super(message);
}

// Auth State
enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? user;
  final String? error;
  final bool isLoading;

  const AuthState({
    required this.status,
    this.user,
    this.error,
    this.isLoading = false,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  factory AuthState.loading() => const AuthState(
        status: AuthStatus.loading,
        isLoading: true,
      );

  factory AuthState.authenticated(String user) => AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );

  factory AuthState.unauthenticated([String? error]) => AuthState(
        status: AuthStatus.unauthenticated,
        error: error,
      );

  AuthState copyWith({
    AuthStatus? status,
    String? user,
    String? error,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error ?? this.error,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.status == status &&
        other.user == user &&
        other.error == error &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return status.hashCode ^ user.hashCode ^ error.hashCode ^ isLoading.hashCode;
  }
}
