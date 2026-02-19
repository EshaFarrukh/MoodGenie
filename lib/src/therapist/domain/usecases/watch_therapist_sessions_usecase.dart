import '../entities/session_entity.dart';
import '../repositories/therapist_repository.dart';

/// Use case for watching therapist sessions
class WatchTherapistSessionsUseCase {
  final TherapistRepository _repository;

  const WatchTherapistSessionsUseCase(this._repository);

  /// Watches all sessions for a specific therapist
  /// Returns a stream of sessions where the user is the therapist
  Stream<List<SessionEntity>> call(String therapistId) {
    if (therapistId.trim().isEmpty) {
      throw ArgumentError('Therapist ID cannot be empty');
    }

    return _repository.watchTherapistSessions(therapistId);
  }

  /// Watches only upcoming sessions for a therapist
  Stream<List<SessionEntity>> upcomingOnly(String therapistId) {
    return call(therapistId).map((sessions) {
      final now = DateTime.now();
      return sessions
          .where((session) =>
              session.scheduledAt.isAfter(now) &&
              (session.status == SessionStatus.requested ||
               session.status == SessionStatus.accepted))
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    });
  }

  /// Watches only pending sessions (requests) for a therapist
  Stream<List<SessionEntity>> pendingOnly(String therapistId) {
    return call(therapistId).map((sessions) {
      return sessions
          .where((session) => session.status == SessionStatus.requested)
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    });
  }

  /// Watches only completed sessions for a therapist
  Stream<List<SessionEntity>> completedOnly(String therapistId) {
    return call(therapistId).map((sessions) {
      return sessions
          .where((session) => session.status == SessionStatus.completed)
          .toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt)); // Most recent first
    });
  }

  /// Watches sessions by status for a therapist
  Stream<List<SessionEntity>> byStatus(String therapistId, SessionStatus status) {
    return call(therapistId).map((sessions) {
      return sessions
          .where((session) => session.status == status)
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    });
  }
}
