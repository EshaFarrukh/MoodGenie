import '../entities/session_entity.dart';

/// Repository contract for session-related operations
abstract class SessionRepository {
  /// Requests a new therapy session
  /// Validates scheduling constraints and therapist availability
  Future<String> requestSession({
    required String userId,
    required String therapistId,
    required DateTime scheduledAt,
    String? notes,
  });

  /// Accepts a pending session request (therapist action)
  /// Updates session status and may create meeting room
  Future<void> acceptSession(String sessionId, {String? meetingRoomId});

  /// Rejects a pending session request (therapist action)
  /// Updates session status with optional reason
  Future<void> rejectSession(String sessionId, {String? reason});

  /// Completes a session (therapist action)
  /// Updates session status and adds completion notes
  Future<void> completeSession(String sessionId, {String? notes});

  /// Cancels a session (user or therapist action)
  /// Updates session status with cancellation reason
  Future<void> cancelSession(String sessionId, {String? reason});

  /// Watches sessions for a specific user
  /// Returns all sessions where the user is the client
  Stream<List<SessionEntity>> watchUserSessions(String userId);

  /// Watches sessions for a specific therapist
  /// Returns all sessions where the user is the therapist
  Stream<List<SessionEntity>> watchTherapistSessions(String therapistId);

  /// Gets a single session by ID
  Future<SessionEntity?> getSessionById(String sessionId);

  /// Gets upcoming sessions for a user
  Future<List<SessionEntity>> getUpcomingSessions(String userId);

  /// Gets session history for a user
  Future<List<SessionEntity>> getSessionHistory(String userId, {int limit = 20});

  /// Checks if a time slot is available for booking
  Future<bool> isTimeSlotAvailable(String therapistId, DateTime scheduledAt);

  /// Gets conflicting sessions for a therapist at a specific time
  Future<List<SessionEntity>> getConflictingSessions(
    String therapistId,
    DateTime startTime,
    DateTime endTime,
  );

  /// Reschedules an existing session
  Future<void> rescheduleSession(String sessionId, DateTime newScheduledAt);
}
