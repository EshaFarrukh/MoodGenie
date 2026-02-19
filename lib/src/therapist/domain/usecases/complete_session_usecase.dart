import '../entities/session_entity.dart';
import '../repositories/session_repository.dart';

/// Use case for completing a therapy session
class CompleteSessionUseCase {
  final SessionRepository _repository;

  const CompleteSessionUseCase(this._repository);

  /// Completes a therapy session
  /// Validates the session can be completed and adds completion notes
  Future<void> call(String sessionId, {String? notes}) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('Session ID cannot be empty');
    }

    // Get the session to validate it can be completed
    final session = await _repository.getSessionById(sessionId);
    if (session == null) {
      throw StateError('Session not found');
    }

    // Validate session can be completed
    if (!session.canBeCompleted()) {
      throw StateError(
        'Session cannot be completed. Current status: ${session.status.displayName}'
      );
    }

    // Additional validation: Session should have started
    final sessionStart = session.scheduledAt;
    final now = DateTime.now();

    if (now.isBefore(sessionStart.subtract(const Duration(minutes: 15)))) {
      throw StateError('Session cannot be completed before it has started');
    }

    // Validate completion notes
    if (notes != null) {
      if (notes.trim().isEmpty) {
        throw ArgumentError('Completion notes cannot be empty');
      }

      if (notes.length > 1000) {
        throw ArgumentError('Completion notes cannot exceed 1000 characters');
      }

      // Validate notes contain some meaningful content
      if (notes.trim().length < 10) {
        throw ArgumentError('Completion notes must be at least 10 characters');
      }

      // Check for required sections in professional notes
      final lowerNotes = notes.toLowerCase();
      final hasAssessment = lowerNotes.contains('assess') ||
                           lowerNotes.contains('evaluat') ||
                           lowerNotes.contains('progress');

      final hasObservation = lowerNotes.contains('observ') ||
                            lowerNotes.contains('behav') ||
                            lowerNotes.contains('mood');

      if (!hasAssessment && !hasObservation) {
        throw ArgumentError(
          'Completion notes should include assessment or observations'
        );
      }
    }

    // Validate session timing
    final maxSessionTime = sessionStart.add(const Duration(hours: 2));
    if (now.isAfter(maxSessionTime)) {
      // Session is very late - may need special handling
      print('Warning: Session completed ${now.difference(sessionStart).inMinutes} minutes after scheduled time');
    }

    // Complete the session
    await _repository.completeSession(sessionId, notes: notes);
  }

  /// Convenience method for completing with minimal notes
  Future<void> completeSimple(String sessionId, String outcome) async {
    final notes = 'Session completed. Outcome: $outcome';
    await call(sessionId, notes: notes);
  }

  /// Convenience method for completing with structured notes
  Future<void> completeWithStructuredNotes({
    required String sessionId,
    required String assessment,
    required String progress,
    String? nextSteps,
    String? observations,
  }) async {
    final notesBuffer = StringBuffer();

    notesBuffer.writeln('Assessment: $assessment');
    notesBuffer.writeln('Progress: $progress');

    if (observations != null && observations.isNotEmpty) {
      notesBuffer.writeln('Observations: $observations');
    }

    if (nextSteps != null && nextSteps.isNotEmpty) {
      notesBuffer.writeln('Next Steps: $nextSteps');
    }

    await call(sessionId, notes: notesBuffer.toString());
  }

  /// Convenience method for emergency completion (session ended abruptly)
  Future<void> completeEmergency(String sessionId, String reason) async {
    final notes = 'Session ended early due to: $reason. '
                 'Please schedule follow-up if needed.';
    await call(sessionId, notes: notes);
  }
}
