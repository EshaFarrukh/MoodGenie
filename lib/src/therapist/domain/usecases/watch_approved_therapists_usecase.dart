import '../entities/therapist_entity.dart';
import '../repositories/therapist_repository.dart';

/// Parameters for watching approved therapists
class WatchApprovedTherapistsParams {
  final String? specialization;
  final double? minRating;
  final int? maxExperienceYears;
  final int? minExperienceYears;
  final bool availableOnly;

  const WatchApprovedTherapistsParams({
    this.specialization,
    this.minRating,
    this.maxExperienceYears,
    this.minExperienceYears,
    this.availableOnly = false,
  });

  /// Validates the parameters
  List<String> validate() {
    final errors = <String>[];

    if (minRating != null && (minRating! < 0.0 || minRating! > 5.0)) {
      errors.add('Minimum rating must be between 0.0 and 5.0');
    }

    if (minExperienceYears != null && minExperienceYears! < 0) {
      errors.add('Minimum experience years cannot be negative');
    }

    if (maxExperienceYears != null && maxExperienceYears! < 0) {
      errors.add('Maximum experience years cannot be negative');
    }

    if (minExperienceYears != null &&
        maxExperienceYears != null &&
        minExperienceYears! > maxExperienceYears!) {
      errors.add('Minimum experience years cannot be greater than maximum');
    }

    return errors;
  }
}

/// Use case for watching approved therapists with filtering
class WatchApprovedTherapistsUseCase {
  final TherapistRepository _repository;

  const WatchApprovedTherapistsUseCase(this._repository);

  /// Watches approved therapists with optional filtering
  /// Returns a stream of therapist lists that match the criteria
  Stream<List<TherapistEntity>> call([WatchApprovedTherapistsParams? params]) {
    // Validate parameters if provided
    if (params != null) {
      final validationErrors = params.validate();
      if (validationErrors.isNotEmpty) {
        throw ArgumentError('Invalid parameters: ${validationErrors.join(', ')}');
      }
    }

    // Set default parameters
    params ??= const WatchApprovedTherapistsParams();

    return _repository.watchApprovedTherapists(
      specialization: params.specialization,
      minRating: params.minRating,
      maxExperienceYears: params.maxExperienceYears,
      minExperienceYears: params.minExperienceYears,
      availableOnly: params.availableOnly,
    );
  }

  /// Convenience method for watching therapists by specialization
  Stream<List<TherapistEntity>> bySpecialization(String specialization) {
    if (specialization.trim().isEmpty) {
      throw ArgumentError('Specialization cannot be empty');
    }

    return call(WatchApprovedTherapistsParams(specialization: specialization));
  }

  /// Convenience method for watching highly rated therapists
  Stream<List<TherapistEntity>> highlyRated({double minRating = 4.0}) {
    return call(WatchApprovedTherapistsParams(minRating: minRating));
  }

  /// Convenience method for watching available therapists only
  Stream<List<TherapistEntity>> availableOnly() {
    return call(const WatchApprovedTherapistsParams(availableOnly: true));
  }

  /// Convenience method for watching experienced therapists
  Stream<List<TherapistEntity>> experienced({int minYears = 5}) {
    return call(WatchApprovedTherapistsParams(minExperienceYears: minYears));
  }
}
