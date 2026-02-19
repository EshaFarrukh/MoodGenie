import '../entities/session_entity.dart';
import '../repositories/session_repository.dart';

/// Use case for cancelling a therapy session
class CancelSessionUseCase {
  final SessionRepository _repository;

  const CancelSessionUseCase(this._repository);

  /// Cancels a therapy session
  /// Validates the session can be cancelled and provides cancellation reason
  Future<void> call(String sessionId, {String? reason}) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('Session ID cannot be empty');
    }

    // Get the session to validate it can be cancelled
    final session = await _repository.getSessionById(sessionId);
    if (session == null) {
      throw StateError('Session not found');
    }

    // Validate session can be cancelled
    if (!session.canBeCancelled()) {
      throw StateError(
        'Session cannot be cancelled. Current status: ${session.status.displayName}'
      );
    }

    // Validate cancellation timing
    final now = DateTime.now();
    final timeDifference = session.scheduledAt.difference(now);

    // Check minimum notice period (24 hours for non-emergency)
    if (timeDifference.inHours < 24 && reason?.toLowerCase() != 'emergency') {
      // Still allow, but may incur fees or affect rating
      print('Warning: Cancellation with less than 24 hours notice');
    }

    // Validate cancellation after session started
    if (session.scheduledAt.isBefore(now)) {
      if (session.status == SessionStatus.accepted) {
        // This might be a no-show scenario
        throw StateError(
          'Session has already started. Use complete session or mark as no-show instead.'
        );
      }
    }

    // Validate reason if provided
    if (reason != null) {
      if (reason.trim().isEmpty) {
        throw ArgumentError('Cancellation reason cannot be empty');
      }

      if (reason.length > 500) {
        throw ArgumentError('Cancellation reason cannot exceed 500 characters');
      }

      // Check for valid cancellation reasons
      final validReasons = [
        'emergency', 'illness', 'technical', 'personal',
        'scheduling', 'travel', 'family', 'work'
      ];

      final lowerReason = reason.toLowerCase();
      final hasValidReason = validReasons.any((valid) =>
        lowerReason.contains(valid)
      );

      if (!hasValidReason && reason.length < 10) {
        throw ArgumentError('Please provide a more detailed cancellation reason');
      }
    }

    // Cancel the session
    await _repository.cancelSession(sessionId, reason: reason);
  }

  /// Convenience method for cancelling without reason
  Future<void> cancelSimple(String sessionId) async {
    await call(sessionId, reason: 'Session cancelled by user');
  }

  /// Convenience method for emergency cancellation
  Future<void> cancelEmergency(String sessionId, String details) async {
    await call(sessionId, reason: 'Emergency: $details');
  }

  /// Convenience method for cancelling with predefined reasons
  Future<void> cancelWithReason(String sessionId, CancellationReason reason) async {
    await call(sessionId, reason: reason.message);
  }

  /// Convenience method for illness cancellation
  Future<void> cancelDueToIllness(String sessionId) async {
    await call(sessionId, reason: 'Unable to attend due to illness');
  }

  /// Convenience method for technical issues
  Future<void> cancelDueToTechnicalIssues(String sessionId) async {
    await call(sessionId, reason: 'Technical difficulties preventing session');
  }
}

/// Predefined cancellation reasons
enum CancellationReason {
  illness('Unable to attend due to illness'),
  emergency('Emergency situation requires cancellation'),
  technical('Technical difficulties preventing session'),
  personalEmergency('Personal emergency'),
  schedulingConflict('Scheduling conflict arose'),
  travelIssues('Travel or transportation issues'),
  familyEmergency('Family emergency'),
  workConflict('Work conflict that cannot be rescheduled'),
  weatherConditions('Severe weather conditions'),
  equipmentFailure('Equipment failure or technical issues');

  const CancellationReason(this.message);

  final String message;

  @override
  String toString() => message;
}
