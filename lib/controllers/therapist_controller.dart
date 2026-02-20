import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/session_model.dart';
import '../src/auth/models/user_model.dart';
import '../services/therapist_service.dart';

class TherapistController extends ChangeNotifier {
  final TherapistService _service = TherapistService();
  
  String get currentTherapistId => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _error;
  String? get error => _error;

  Stream<List<SessionModel>> get todaySessions => _service.getTodaySessions(currentTherapistId);
  Stream<List<SessionModel>> get pendingRequests => _service.getPendingRequests(currentTherapistId);
  Stream<List<AppUser>> get assignedUsers => _service.getAssignedUsers(currentTherapistId);

  Future<void> acceptSession(String sessionId) async {
    return _updateSessionStatus(sessionId, 'accepted');
  }

  Future<void> rejectSession(String sessionId) async {
    return _updateSessionStatus(sessionId, 'rejected');
  }

  Future<void> markSessionCompleted(String sessionId) async {
    return _updateSessionStatus(sessionId, 'completed');
  }

  Future<void> _updateSessionStatus(String sessionId, String status) async {
    if (currentTherapistId.isEmpty) return;
    try {
      _setLoading(true);
      await _service.updateSessionStatus(sessionId, status);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<String> startVideoSession(String sessionId) async {
    if (currentTherapistId.isEmpty) throw Exception("Unauthorized");
    try {
      _setLoading(true);
      final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}';
      await _service.startVideoSession(sessionId, roomId);
      _clearError();
      return roomId;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
