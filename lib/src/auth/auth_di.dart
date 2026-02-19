import 'models/user_model.dart';
import 'repositories/auth_repository.dart';
import 'usecases/auth_usecases.dart';
import 'usecases/user_signup_usecase.dart';
import 'services/auth_service.dart';

class AuthDependencyInjection {
  static AuthRepository? _repository;
  static AuthService? _authService;

  static AuthRepository get repository {
    return _repository ??= FirebaseAuthRepository();
  }

  static AuthService get authService {
    if (_authService != null) return _authService!;

    final repo = repository;

    _authService = AuthService(
      signUpTherapistUseCase: SignUpTherapistUseCase(repo),
      signUpUserUseCase: SignUpUserUseCase(repo),
      signInUseCase: SignInUseCase(repo),
      signOutUseCase: SignOutUseCase(repo),
      getCurrentUserUseCase: GetCurrentUserUseCase(repo),
      repository: repo,
    );

    return _authService!;
  }

  static void dispose() {
    _authService = null;
    _repository = null;
  }
}
