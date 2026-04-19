import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/session_model.dart';
import '../screens/therapist/models/therapist_workspace_models.dart';
import '../services/therapist_service.dart';
import '../src/auth/models/user_model.dart';
import '../src/services/backend_api_client.dart';
import '../src/services/secure_operations_service.dart';

class TherapistController extends ChangeNotifier {
  TherapistController({
    TherapistService? service,
    SecureOperationsService? secureOperations,
  }) : _service = service ?? TherapistService(),
       _secureOperations = secureOperations ?? SecureOperationsService() {
    unawaited(loadInitialPatients());
  }

  final TherapistService _service;
  final SecureOperationsService _secureOperations;

  String get currentTherapistId => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final Set<String> _busySessionIds = <String>{};
  TherapistUiNotice? _dashboardNotice;
  TherapistUiNotice? get dashboardNotice => _dashboardNotice;
  bool isSessionBusy(String sessionId) => _busySessionIds.contains(sessionId);

  Stream<TherapistDashboardHeader> get dashboardHeader {
    final id = currentTherapistId;
    if (id.isEmpty) {
      return const Stream<TherapistDashboardHeader>.empty();
    }
    return _service.watchDashboardHeader(id);
  }

  Stream<TherapistProfile?> get profileStream {
    final id = currentTherapistId;
    if (id.isEmpty) {
      return const Stream<TherapistProfile?>.empty();
    }
    return _service.getTherapistProfile(id);
  }

  final List<TherapistPatientSummary> _patientSummaries =
      <TherapistPatientSummary>[];
  QueryDocumentSnapshot<Map<String, dynamic>>? _patientCursor;
  bool _isPatientsLoading = false;
  bool _isLoadingMorePatients = false;
  bool _hasMorePatients = true;

  List<TherapistPatientSummary> get patientSummaries => _patientSummaries;
  bool get isPatientsLoading => _isPatientsLoading;
  bool get isLoadingMorePatients => _isLoadingMorePatients;
  bool get hasMorePatients => _hasMorePatients;

  final List<TherapistScheduleItem> _scheduleItems = <TherapistScheduleItem>[];
  QueryDocumentSnapshot<Map<String, dynamic>>? _scheduleCursor;
  bool _isScheduleLoading = false;
  bool _isLoadingMoreSchedule = false;
  bool _hasMoreSchedule = true;
  TherapistScheduleView _scheduleView = TherapistScheduleView.today;
  TherapistScheduleStatusFilter _scheduleStatusFilter =
      TherapistScheduleStatusFilter.all;
  int _scheduleRequestVersion = 0;

  List<TherapistScheduleItem> get scheduleItems => _scheduleItems;
  bool get isScheduleLoading => _isScheduleLoading;
  bool get isLoadingMoreSchedule => _isLoadingMoreSchedule;
  bool get hasMoreSchedule => _hasMoreSchedule;
  TherapistScheduleView get scheduleView => _scheduleView;
  TherapistScheduleStatusFilter get scheduleStatusFilter =>
      _scheduleStatusFilter;

  Future<void> loadInitialPatients({bool force = false}) async {
    if (currentTherapistId.isEmpty || _isPatientsLoading) {
      return;
    }
    if (!force && _patientSummaries.isNotEmpty) {
      return;
    }

    _isPatientsLoading = true;
    if (force) {
      _patientSummaries.clear();
      _patientCursor = null;
      _hasMorePatients = true;
    }
    notifyListeners();

    try {
      final result = await _service.loadPatientSummariesPage(
        currentTherapistId,
      );
      _patientSummaries
        ..clear()
        ..addAll(result.items);
      _patientCursor = result.nextCursor;
      _hasMorePatients = result.hasMore;
    } catch (e) {
      // Silently handle query failures (e.g., missing indexes)
      _hasMorePatients = false;
    } finally {
      _isPatientsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePatients() async {
    if (currentTherapistId.isEmpty ||
        _isLoadingMorePatients ||
        !_hasMorePatients ||
        _patientCursor == null) {
      return;
    }

    _isLoadingMorePatients = true;
    notifyListeners();

    try {
      final result = await _service.loadPatientSummariesPage(
        currentTherapistId,
        cursor: _patientCursor,
      );
      _patientSummaries.addAll(result.items);
      _patientCursor = result.nextCursor;
      _hasMorePatients = result.hasMore;
    } finally {
      _isLoadingMorePatients = false;
      notifyListeners();
    }
  }

  Future<void> refreshPatients() {
    return loadInitialPatients(force: true);
  }

  Future<void> loadInitialSchedule({
    TherapistScheduleView? view,
    TherapistScheduleStatusFilter? statusFilter,
    bool force = false,
  }) async {
    if (currentTherapistId.isEmpty || _isScheduleLoading) {
      return;
    }

    final nextView = view ?? _scheduleView;
    final nextStatusFilter = statusFilter ?? _scheduleStatusFilter;
    final filtersChanged =
        nextView != _scheduleView || nextStatusFilter != _scheduleStatusFilter;
    if (!force && !filtersChanged && _scheduleItems.isNotEmpty) {
      return;
    }

    _scheduleView = nextView;
    _scheduleStatusFilter = nextStatusFilter;
    _scheduleRequestVersion += 1;
    final requestVersion = _scheduleRequestVersion;

    _scheduleItems.clear();
    _scheduleCursor = null;
    _hasMoreSchedule = true;
    _isScheduleLoading = true;
    notifyListeners();

    try {
      final result = await _service.loadSchedulePage(
        currentTherapistId,
        view: _scheduleView,
        statusFilter: _scheduleStatusFilter,
      );
      if (requestVersion != _scheduleRequestVersion) {
        return;
      }
      _scheduleItems.addAll(result.items);
      _scheduleCursor = result.nextCursor;
      _hasMoreSchedule = result.hasMore;
    } finally {
      if (requestVersion == _scheduleRequestVersion) {
        _isScheduleLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreSchedule() async {
    if (currentTherapistId.isEmpty ||
        _isLoadingMoreSchedule ||
        !_hasMoreSchedule ||
        _scheduleCursor == null) {
      return;
    }

    final requestVersion = _scheduleRequestVersion;
    _isLoadingMoreSchedule = true;
    notifyListeners();

    try {
      final result = await _service.loadSchedulePage(
        currentTherapistId,
        view: _scheduleView,
        statusFilter: _scheduleStatusFilter,
        cursor: _scheduleCursor,
      );
      if (requestVersion != _scheduleRequestVersion) {
        return;
      }
      _scheduleItems.addAll(result.items);
      _scheduleCursor = result.nextCursor;
      _hasMoreSchedule = result.hasMore;
    } finally {
      if (requestVersion == _scheduleRequestVersion) {
        _isLoadingMoreSchedule = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshSchedule() {
    return loadInitialSchedule(
      view: _scheduleView,
      statusFilter: _scheduleStatusFilter,
      force: true,
    );
  }

  Future<AppUser?> getUserById(String userId) {
    return _service.getUserById(userId);
  }

  Future<void> acceptSession(String sessionId) async {
    return _updateSessionStatus(sessionId, AppointmentStatus.confirmed);
  }

  Future<void> rejectSession(String sessionId, {String? reason}) async {
    return _updateSessionStatus(
      sessionId,
      AppointmentStatus.rejected,
      reason: reason,
    );
  }

  Future<void> markSessionCompleted(String sessionId) async {
    return _updateSessionStatus(sessionId, AppointmentStatus.completed);
  }

  Future<void> cancelSession(String sessionId, {String? reason}) async {
    return _updateSessionStatus(
      sessionId,
      AppointmentStatus.cancelled,
      reason: reason,
    );
  }

  Future<void> markSessionNoShow(String sessionId, {String? reason}) async {
    return _updateSessionStatus(
      sessionId,
      AppointmentStatus.noShow,
      reason: reason,
    );
  }

  Future<void> _updateSessionStatus(
    String sessionId,
    AppointmentStatus status, {
    String? reason,
  }) async {
    if (currentTherapistId.isEmpty) {
      return;
    }
    try {
      _beginAction(sessionId);
      await _secureOperations.updateAppointmentStatus(
        sessionId,
        status,
        reason: reason,
      );
      _service.invalidatePatientCount(currentTherapistId);
      clearDashboardNotice();
      unawaited(refreshPatients());
      unawaited(refreshSchedule());
    } catch (e) {
      _setDashboardNotice(_mapErrorToNotice(e));
      rethrow;
    } finally {
      _endAction(sessionId);
    }
  }

  Future<String> startVideoSession(String sessionId) async {
    if (currentTherapistId.isEmpty) {
      throw Exception('Unauthorized');
    }
    try {
      _beginAction(sessionId);
      final room = await _secureOperations.ensureAppointmentCallRoom(sessionId);
      clearDashboardNotice();
      return room.roomId;
    } catch (e) {
      _setDashboardNotice(_mapErrorToNotice(e));
      rethrow;
    } finally {
      _endAction(sessionId);
    }
  }

  void dismissDashboardNotice() {
    if (_dashboardNotice == null) {
      return;
    }
    _dashboardNotice = null;
    notifyListeners();
  }

  void clearDashboardNotice() {
    if (_dashboardNotice == null) {
      return;
    }
    _dashboardNotice = null;
    notifyListeners();
  }

  TherapistUiNotice _mapErrorToNotice(Object error) {
    if (error is BackendApiException &&
        (error.code == 'calling_unavailable' ||
            error.code == 'appointment_not_call_ready')) {
      return const TherapistUiNotice(
        title: 'Secure call unavailable',
        message:
            'This session is not ready for calling yet. Confirm the appointment and try again.',
        icon: Icons.videocam_off_rounded,
      );
    }

    final message = error.toString();
    if (message.toLowerCase().contains('timeoutexception')) {
      return const TherapistUiNotice(
        title: 'The request took too long',
        message:
            'We could not finish that secure action in time. Please try again in a moment.',
        icon: Icons.schedule_send_rounded,
      );
    }

    return TherapistUiNotice(
      title: 'Action not completed',
      message: message.replaceFirst('Exception: ', ''),
      icon: Icons.error_outline_rounded,
    );
  }

  void _beginAction(String sessionId) {
    _busySessionIds.add(sessionId);
    _isLoading = _busySessionIds.isNotEmpty;
    notifyListeners();
  }

  void _endAction(String sessionId) {
    _busySessionIds.remove(sessionId);
    _isLoading = _busySessionIds.isNotEmpty;
    notifyListeners();
  }

  void _setDashboardNotice(TherapistUiNotice notice) {
    _dashboardNotice = notice;
    notifyListeners();
  }
}
