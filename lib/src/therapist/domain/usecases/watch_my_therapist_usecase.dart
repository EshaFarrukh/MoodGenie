import '../entities/therapist_entity.dart';
import '../repositories/therapist_repository.dart';

/// Use case for watching therapist profile data
class WatchMyTherapistUseCase {
  final TherapistRepository _repository;

  const WatchMyTherapistUseCase(this._repository);

  /// Watches the current user's therapist profile
  /// Returns a stream that emits profile updates
  Stream<TherapistEntity?> call(String uid) {
    if (uid.trim().isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    return _repository.watchMyTherapist(uid);
  }
}
