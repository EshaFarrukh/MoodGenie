import '../entities/therapist_entity.dart';
import '../repositories/therapist_repository.dart';

/// Use case for creating or updating therapist profiles
class UpsertTherapistProfileUseCase {
  final TherapistRepository _repository;

  const UpsertTherapistProfileUseCase(this._repository);

  /// Creates or updates a therapist profile
  /// Validates the profile data before saving
  Future<void> call(TherapistEntity entity) async {
    // Validate the entity
    final validationErrors = entity.validate();
    if (validationErrors.isNotEmpty) {
      throw ValidationException(validationErrors);
    }

    // Additional business rule validations
    await _validateBusinessRules(entity);

    // Save the profile
    await _repository.upsertProfile(entity);
  }

  /// Validates business rules for therapist profiles
  Future<void> _validateBusinessRules(TherapistEntity entity) async {
    // Check for duplicate availability slots
    final slots = entity.availabilitySlots;
    for (int i = 0; i < slots.length; i++) {
      for (int j = i + 1; j < slots.length; j++) {
        if (slots[i].overlapsWith(slots[j])) {
          throw ValidationException([
            'Availability slots cannot overlap: ${slots[i]} and ${slots[j]}'
          ]);
        }
      }
    }

    // Validate minimum experience for certain specializations
    final criticalSpecializations = [
      'Child Psychology',
      'Trauma Therapy',
      'Addiction Counseling',
    ];

    if (criticalSpecializations.contains(entity.specialization) &&
        entity.experienceYears < 2) {
      throw ValidationException([
        'Minimum 2 years experience required for ${entity.specialization}'
      ]);
    }

    // Validate reasonable working hours (max 8 slots per day)
    final dailySlots = <String, int>{};
    for (final slot in entity.availabilitySlots) {
      final dateKey = '${slot.startAt.year}-${slot.startAt.month}-${slot.startAt.day}';
      dailySlots[dateKey] = (dailySlots[dateKey] ?? 0) + 1;
    }

    for (final entry in dailySlots.entries) {
      if (entry.value > 8) {
        throw ValidationException([
          'Cannot have more than 8 availability slots per day (${entry.key})'
        ]);
      }
    }
  }
}

/// Exception thrown when validation fails
class ValidationException implements Exception {
  final List<String> errors;

  const ValidationException(this.errors);

  @override
  String toString() {
    return 'ValidationException: ${errors.join(', ')}';
  }
}
