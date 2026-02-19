import '../entities/therapist_entity.dart';
import '../repositories/therapist_repository.dart';
import 'upsert_therapist_profile_usecase.dart';

/// Use case for updating therapist availability slots
class UpdateAvailabilityUseCase {
  final TherapistRepository _repository;

  const UpdateAvailabilityUseCase(this._repository);

  /// Updates availability slots for a therapist
  /// Validates slots for conflicts and business rules
  Future<void> call(String uid, List<AvailabilitySlotEntity> slots) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    // Validate all slots
    final allErrors = <String>[];
    for (int i = 0; i < slots.length; i++) {
      final slotErrors = slots[i].validate();
      allErrors.addAll(slotErrors.map((error) => 'Slot ${i + 1}: $error'));
    }

    if (allErrors.isNotEmpty) {
      throw ValidationException(allErrors);
    }

    // Check for overlapping slots
    for (int i = 0; i < slots.length; i++) {
      for (int j = i + 1; j < slots.length; j++) {
        if (slots[i].overlapsWith(slots[j])) {
          throw ValidationException([
            'Slots ${i + 1} and ${j + 1} overlap: ${slots[i]} and ${slots[j]}'
          ]);
        }
      }
    }

    // Validate reasonable daily limits
    await _validateDailyLimits(slots);

    // Validate future scheduling only
    final now = DateTime.now();
    for (int i = 0; i < slots.length; i++) {
      if (slots[i].startAt.isBefore(now)) {
        throw ValidationException([
          'Slot ${i + 1}: Cannot set availability in the past'
        ]);
      }
    }

    // Update availability
    await _repository.updateAvailability(uid, slots);
  }

  /// Validates daily slot limits
  Future<void> _validateDailyLimits(List<AvailabilitySlotEntity> slots) async {
    final dailySlots = <String, List<AvailabilitySlotEntity>>{};

    // Group slots by day
    for (final slot in slots) {
      final dateKey = '${slot.startAt.year}-${slot.startAt.month}-${slot.startAt.day}';
      dailySlots.putIfAbsent(dateKey, () => []).add(slot);
    }

    final errors = <String>[];

    for (final entry in dailySlots.entries) {
      final daySlots = entry.value;
      final date = entry.key;

      // Check maximum slots per day
      if (daySlots.length > 8) {
        errors.add('Cannot have more than 8 slots on $date');
      }

      // Check total working hours per day
      var totalMinutes = 0;
      for (final slot in daySlots) {
        totalMinutes += slot.endAt.difference(slot.startAt).inMinutes;
      }

      if (totalMinutes > 480) { // 8 hours
        errors.add('Cannot work more than 8 hours on $date');
      }

      // Check minimum break between slots
      final sortedSlots = List<AvailabilitySlotEntity>.from(daySlots)
        ..sort((a, b) => a.startAt.compareTo(b.startAt));

      for (int i = 0; i < sortedSlots.length - 1; i++) {
        final currentSlot = sortedSlots[i];
        final nextSlot = sortedSlots[i + 1];
        final break_ = nextSlot.startAt.difference(currentSlot.endAt);

        if (break_.inMinutes < 15) {
          errors.add('Minimum 15-minute break required between slots on $date');
        }
      }

      // Check business hours (9 AM to 6 PM)
      for (final slot in daySlots) {
        if (slot.startAt.hour < 9 || slot.endAt.hour > 18) {
          errors.add('Slots must be between 9 AM and 6 PM on $date');
        }
      }

      // Check weekdays only
      if (daySlots.isNotEmpty) {
        final weekday = daySlots.first.startAt.weekday;
        if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
          errors.add('Cannot set availability on weekends ($date)');
        }
      }
    }

    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }
}
