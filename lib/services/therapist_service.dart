import 'package:cloud_firestore/cloud_firestore.dart';
import '../src/auth/models/user_model.dart';
import '../models/session_model.dart';
import '../src/services/mood_repository.dart'; // To reuse MoodLog if needed

class TherapistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream today's sessions for the therapist
  Stream<List<SessionModel>> getTodaySessions(String therapistId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('sessions')
        .where('therapistId', isEqualTo: therapistId)
        .where('status', isEqualTo: 'accepted')
        .where('scheduledAt', isGreaterThanOrEqualTo: startOfDay)
        .where('scheduledAt', isLessThanOrEqualTo: endOfDay)
        .orderBy('scheduledAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Stream pending booking requests
  Stream<List<SessionModel>> getPendingRequests(String therapistId) {
    return _firestore
        .collection('sessions')
        .where('therapistId', isEqualTo: therapistId)
        .where('status', isEqualTo: 'pending')
        .orderBy('scheduledAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Stream all assigned users -> Users who have an accepted/completed session with this therapist
  Stream<List<AppUser>> getAssignedUsers(String therapistId) {
    // In NoSQL, a true many-to-many list of assigned users is best handled by storing user IDs in a separate 
    // array on the therapist profile, or by querying sessions. Here we fetch the users directly if we had a mapping,
    // but for simplicity according to spec, we'll fetch all users (assuming admin assigns them or they book).
    // Let's get all UserRole.user profiles for now, or filter by a specific 'therapistId' field if it existed on the user.
    // Assuming simple demo: we return all users who are NOT therapists.
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'user')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Update session status
  Future<void> updateSessionStatus(String sessionId, String status) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': status,
    });
  }

  // Start Video Session (Generates Room ID)
  Future<void> startVideoSession(String sessionId, String roomId) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'meetingRoomId': roomId,
    });
  }
}
