import '../repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../models/auth_models.dart';

class SignUpUserUseCase {
  final AuthRepository _repository;

  SignUpUserUseCase(this._repository);

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
      role: UserRole.user,
      name: name,
    );
  }
}
