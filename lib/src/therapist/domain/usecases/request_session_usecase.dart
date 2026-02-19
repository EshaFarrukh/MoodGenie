import '../repositories/session_repository.dart';

/// Parameters for requesting a session
class RequestSessionParams {
  final String userId;
  final String therapistId;
  final DateTime scheduledAt;
  final String? notes;

  const RequestSessionParams({
    required this.userId,
    required this.therapistId,
    required this.scheduledAt,
    this.notes,
  });

  /// Validates the parameters
  List<String> validate() {
    final errors = <String>[];

    if (userId.trim().isEmpty) {
      errors.add('User ID cannot be empty');
    }

    if (therapistId.trim().isEmpty) {
      errors.add('Therapist ID cannot be empty');
    }

    if (userId == therapistId) {
      errors.add('Cannot book session with yourself');
    }

    // Validate scheduling time is in the future
    if (scheduledAt.isBefore(DateTime.now().add(const Duration(hours: 1)))) {
      errors.add('Session must be scheduled at least 1 hour in advance');
    }

    // Validate business hours (9 AM to 6 PM)
    final hour = scheduledAt.hour;
    if (hour < 9 || hour >= 18) {
      errors.add('Sessions must be scheduled between 9 AM and 6 PM');
    }

    // Validate weekdays only
    final weekday = scheduledAt.weekday;
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      errors.add('Sessions can only be scheduled on weekdays');
    }

    // Validate session is on the hour or half-hour
    if (scheduledAt.minute != 0 && scheduledAt.minute != 30) {
      errors.add('Sessions can only be scheduled on the hour or half-hour');
    }

    // Validate not too far in the future (max 30 days)
    final maxAdvance = DateTime.now().add(const Duration(days: 30));
    if (scheduledAt.isAfter(maxAdvance)) {
      errors.add('Sessions cannot be scheduled more than 30 days in advance');
    }

    // Validate notes length
    if (notes != null && notes!.length > 200) {
      errors.add('Notes cannot exceed 200 characters');
    }

    return errors;
  }
}

/// Use case for requesting a therapy session
class RequestSessionUseCase {
  final SessionRepository _repository;

  const RequestSessionUseCase(this._repository);

  /// Requests a new therapy session
  /// Returns the created session ID
  Future<String> call(RequestSessionParams params) async {
    // Validate parameters
    final validationErrors = params.validate();
    if (validationErrors.isNotEmpty) {
      throw ArgumentError('Validation failed: ${validationErrors.join(', ')}');
    }

    // Check if the time slot is available
    final isAvailable = await _repository.isTimeSlotAvailable(
      params.therapistId,
      params.scheduledAt,
    );

    if (!isAvailable) {
      throw StateError('The selected time slot is no longer available');
    }

    // Check for conflicting sessions
    final endTime = params.scheduledAt.add(const Duration(hours: 1));
    final conflicts = await _repository.getConflictingSessions(
      params.therapistId,
      params.scheduledAt,
      endTime,
    );

    if (conflicts.isNotEmpty) {
      throw StateError('There is a scheduling conflict at the selected time');
    }

    // Request the session
    return await _repository.requestSession(
      userId: params.userId,
      therapistId: params.therapistId,
      scheduledAt: params.scheduledAt,
      notes: params.notes,
    );
  }

  /// Convenience method for requesting a session with minimal parameters
  Future<String> requestSimple({
    required String userId,
    required String therapistId,
    required DateTime scheduledAt,
  }) async {
    return await call(RequestSessionParams(
      userId: userId,
      therapistId: therapistId,
      scheduledAt: scheduledAt,
    ));
  }
}
