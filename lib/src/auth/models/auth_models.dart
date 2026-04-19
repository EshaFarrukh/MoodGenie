import 'user_model.dart';

abstract class AuthFailure {
  final String message;
  const AuthFailure(this.message);
}

class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure()
    : super('This email address is already in use.');
}

class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure() : super('The password provided is too weak.');
}

class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure() : super('No user found for that email.');
}

class WrongPasswordFailure extends AuthFailure {
  const WrongPasswordFailure()
    : super('Wrong password provided for that user.');
}

class InvalidEmailFailure extends AuthFailure {
  const InvalidEmailFailure() : super('The email address is not valid.');
}

class UserDisabledFailure extends AuthFailure {
  const UserDisabledFailure() : super('This user account has been disabled.');
}

class NetworkFailure extends AuthFailure {
  const NetworkFailure()
    : super('Network error occurred. Please check your internet connection.');
}

class InvalidCredentialFailure extends AuthFailure {
  const InvalidCredentialFailure()
    : super('Invalid email or password. Please try again.');
}

class TooManyRequestsFailure extends AuthFailure {
  const TooManyRequestsFailure()
    : super('Too many failed attempts. Please try again later.');
}

class ServerFailure extends AuthFailure {
  const ServerFailure()
    : super('Server error occurred. Please try again later.');
}

class UnknownFailure extends AuthFailure {
  const UnknownFailure(super.message);
}

class AuthCancelledFailure extends AuthFailure {
  const AuthCancelledFailure() : super('Sign-in was cancelled.');
}

class RegistrationSuccess {
  final String email;
  final String message;

  const RegistrationSuccess({required this.email, required this.message});
}

// Auth State
enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState {
  static const Object _unset = Object();

  final AuthStatus status;
  final AppUser? user;
  final String? error;
  final bool isLoading;

  const AuthState({
    required this.status,
    this.user,
    this.error,
    this.isLoading = false,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  factory AuthState.loading() =>
      const AuthState(status: AuthStatus.loading, isLoading: true);

  factory AuthState.authenticated(AppUser user) =>
      AuthState(status: AuthStatus.authenticated, user: user);

  factory AuthState.unauthenticated([String? error]) =>
      AuthState(status: AuthStatus.unauthenticated, error: error);

  AuthState copyWith({
    AuthStatus? status,
    Object? user = _unset,
    Object? error = _unset,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user == _unset ? this.user : user as AppUser?,
      error: error == _unset ? this.error : error as String?,
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
    return status.hashCode ^
        user.hashCode ^
        error.hashCode ^
        isLoading.hashCode;
  }
}
