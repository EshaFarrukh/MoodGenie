import '../models/user_model.dart';
import '../models/auth_models.dart';
import '../repositories/auth_repository.dart';

class SignUpTherapistUseCase {
  final AuthRepository _repository;

  SignUpTherapistUseCase(this._repository);

  Future<void> call({
    required String email,
    required String password,
    required String name,
  }) async {
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      throw const InvalidEmailFailure();
    }

    if (password.length < 6) {
      throw const WeakPasswordFailure();
    }

    await _repository.signUpWithEmailAndPassword(
      email,
      password,
      role: UserRole.therapist,
      name: name,
    );
  }
}

class SignInUseCase {
  final AuthRepository _repository;

  SignInUseCase(this._repository);

  Future<void> call({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      throw const InvalidEmailFailure();
    }

    await _repository.signInWithEmailAndPassword(email, password);
  }
}

class SignOutUseCase {
  final AuthRepository _repository;

  SignOutUseCase(this._repository);

  Future<void> call() async {
    await _repository.signOut();
  }
}

class GetCurrentUserUseCase {
  final AuthRepository _repository;

  GetCurrentUserUseCase(this._repository);

  Future<AppUser?> call() async {
    return await _repository.getCurrentUser();
  }
}
