import '../entities/session_entity.dart';
import '../repositories/session_repository.dart';

/// Use case for rejecting a therapy session request
class RejectSessionUseCase {
  final SessionRepository _repository;

  const RejectSessionUseCase(this._repository);

  /// Rejects a pending session request
  /// Validates the session can be rejected and updates status
  Future<void> call(String sessionId, {String? reason}) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('Session ID cannot be empty');
    }

    // Get the session to validate it can be rejected
    final session = await _repository.getSessionById(sessionId);
    if (session == null) {
      throw StateError('Session not found');
    }

    // Validate session can be rejected
    if (!session.canBeRejected()) {
      throw StateError(
        'Session cannot be rejected. Current status: ${session.status.displayName}'
      );
    }

    // Validate reason if provided
    if (reason != null) {
      if (reason.trim().isEmpty) {
        throw ArgumentError('Rejection reason cannot be empty');
      }

      if (reason.length > 500) {
        throw ArgumentError('Rejection reason cannot exceed 500 characters');
      }

      // Check for inappropriate content (basic validation)
      final inappropriateWords = ['hate', 'discriminat', 'bias'];
      final lowerReason = reason.toLowerCase();
      for (final word in inappropriateWords) {
        if (lowerReason.contains(word)) {
          throw ArgumentError('Rejection reason contains inappropriate content');
        }
      }
    }

    // Reject the session
    await _repository.rejectSession(sessionId, reason: reason);
  }

  /// Convenience method for rejecting without reason
  Future<void> rejectSimple(String sessionId) async {
    await call(sessionId);
  }

  /// Convenience method for rejecting with predefined reasons
  Future<void> rejectWithReason(String sessionId, RejectionReason reason) async {
    await call(sessionId, reason: reason.message);
  }
}

/// Predefined rejection reasons
enum RejectionReason {
  timeNotAvailable('The requested time slot is not available'),
  schedulingConflict('There is a scheduling conflict'),
  notSpecialized('This is outside my area of specialization'),
  personalReason('Personal reasons prevent me from accepting this session'),
  technicalIssue('Technical issues prevent me from conducting the session'),
  patientNotSuitable('This case may require specialized care beyond my expertise');

  const RejectionReason(this.message);

  final String message;

  @override
  String toString() => message;
}
