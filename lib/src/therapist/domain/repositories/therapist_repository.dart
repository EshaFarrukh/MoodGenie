import '../entities/therapist_entity.dart';
import '../entities/session_entity.dart';

/// Repository contract for therapist-related operations
abstract class TherapistRepository {
  /// Watches the therapist profile for a specific user ID
  /// Returns a stream of the therapist's profile data
  Stream<TherapistEntity?> watchMyTherapist(String uid);

  /// Creates or updates a therapist profile
  /// Validates the entity before saving
  Future<void> upsertProfile(TherapistEntity entity);

  /// Updates availability slots for a therapist
  /// Validates slots for conflicts and business rules
  Future<void> updateAvailability(String uid, List<AvailabilitySlotEntity> slots);

  /// Watches approved therapists with optional query filtering
  /// Supports filtering by specialization, rating, availability, etc.
  Stream<List<TherapistEntity>> watchApprovedTherapists({
    String? specialization,
    double? minRating,
    int? maxExperienceYears,
    int? minExperienceYears,
    bool availableOnly = false,
  });

  /// Watches sessions for a specific therapist
  /// Returns all sessions where the user is the therapist
  Stream<List<SessionEntity>> watchTherapistSessions(String therapistId);

  /// Approves a therapist (admin only operation)
  /// This is a placeholder for future admin functionality
  Future<void> approveTherapist(String therapistId);

  /// Gets a single therapist by ID
  Future<TherapistEntity?> getTherapistById(String therapistId);

  /// Searches therapists by name or specialization
  Future<List<TherapistEntity>> searchTherapists(String query);

  /// Gets therapist statistics (for dashboard)
  Future<Map<String, dynamic>> getTherapistStats(String therapistId);
}
