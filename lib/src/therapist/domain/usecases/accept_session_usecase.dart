import '../entities/session_entity.dart';
import '../repositories/session_repository.dart';

/// Use case for accepting a therapy session request
class AcceptSessionUseCase {
  final SessionRepository _repository;

  const AcceptSessionUseCase(this._repository);

  /// Accepts a pending session request
  /// Validates the session can be accepted and updates status
  Future<void> call(String sessionId, {String? meetingRoomId}) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('Session ID cannot be empty');
    }

    // Get the session to validate it can be accepted
    final session = await _repository.getSessionById(sessionId);
    if (session == null) {
      throw StateError('Session not found');
    }

    // Validate session can be accepted
    if (!session.canBeAccepted()) {
      throw StateError(
        'Session cannot be accepted. Current status: ${session.status.displayName}'
      );
    }

    // Validate session is not in the past
    if (session.scheduledAt.isBefore(DateTime.now())) {
      throw StateError('Cannot accept a session scheduled in the past');
    }

    // Validate meeting room ID format if provided
    if (meetingRoomId != null) {
      if (meetingRoomId.trim().isEmpty) {
        throw ArgumentError('Meeting room ID cannot be empty');
      }

      if (meetingRoomId.length > 100) {
        throw ArgumentError('Meeting room ID is too long');
      }

      // Basic URL validation for meeting room
      if (!meetingRoomId.startsWith('http') &&
          !meetingRoomId.startsWith('zoom://') &&
          !meetingRoomId.startsWith('teams://') &&
          !meetingRoomId.contains('@')) {
        throw ArgumentError('Invalid meeting room ID format');
      }
    }

    // Check for scheduling conflicts before accepting
    final endTime = session.scheduledAt.add(const Duration(hours: 1));
    final conflicts = await _repository.getConflictingSessions(
      session.therapistId,
      session.scheduledAt,
      endTime,
    );

    // Remove the current session from conflicts
    conflicts.removeWhere((conflict) => conflict.sessionId == sessionId);

    if (conflicts.isNotEmpty) {
      throw StateError('There is a scheduling conflict. Please reject this session.');
    }

    // Accept the session
    await _repository.acceptSession(sessionId, meetingRoomId: meetingRoomId);
  }

  /// Convenience method for accepting without meeting room
  Future<void> acceptSimple(String sessionId) async {
    await call(sessionId);
  }

  /// Convenience method for accepting with Zoom meeting
  Future<void> acceptWithZoom(String sessionId, String zoomUrl) async {
    if (!zoomUrl.contains('zoom.us')) {
      throw ArgumentError('Invalid Zoom URL');
    }
    await call(sessionId, meetingRoomId: zoomUrl);
  }

  /// Convenience method for accepting with Google Meet
  Future<void> acceptWithGoogleMeet(String sessionId, String meetUrl) async {
    if (!meetUrl.contains('meet.google.com')) {
      throw ArgumentError('Invalid Google Meet URL');
    }
    await call(sessionId, meetingRoomId: meetUrl);
  }
}
