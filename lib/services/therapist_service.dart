import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_model.dart';
import '../screens/therapist/models/therapist_workspace_models.dart';
import '../src/auth/models/user_model.dart';

class TherapistService {
  TherapistService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  final Map<String, AppUser> _userCache = <String, AppUser>{};
  final Map<String, List<Map<String, dynamic>>> _recentMoodCache =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, int> _patientCountCache = <String, int>{};

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection('appointments');

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Query<Map<String, dynamic>> _therapistAppointmentsQuery(String therapistId) {
    return _appointments.where('therapistId', isEqualTo: therapistId);
  }

  /// Watches the therapist dashboard using a single Firestore stream on
  /// therapistId (uses the auto-generated single-field index) and derives
  /// all dashboard sections by filtering in memory.
  Stream<TherapistDashboardHeader> watchDashboardHeader(String therapistId) {
    return _therapistAppointmentsQuery(therapistId)
        .snapshots()
        .asyncMap((snapshot) async {
          final now = DateTime.now();
          final startOfToday = _startOfDay(now);
          final startOfTomorrow = startOfToday.add(const Duration(days: 1));
          final endOfWeek = startOfToday.add(const Duration(days: 7));

          final allSessions = snapshot.docs
              .map((doc) => SessionModel.fromMap(doc.data(), doc.id))
              .toList();

          final pendingSessions = allSessions
              .where((s) => s.status == AppointmentStatus.requested)
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

          final todaySessions = allSessions
              .where((s) =>
                  s.status == AppointmentStatus.confirmed &&
                  !s.scheduledAt.isBefore(startOfToday) &&
                  s.scheduledAt.isBefore(startOfTomorrow))
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

          final weekSessions = allSessions
              .where((s) =>
                  !s.scheduledAt.isBefore(startOfToday) &&
                  s.scheduledAt.isBefore(endOfWeek))
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

          final userIds = <String>{
            ...pendingSessions.map((s) => s.userId),
            ...todaySessions.map((s) => s.userId),
            ...weekSessions.map((s) => s.userId),
          }.where((id) => id.isNotEmpty).toList();

          final usersById = await _fetchUsersByIds(userIds);

          final patientCount = allSessions
              .map((s) => s.userId)
              .where((id) => id.isNotEmpty)
              .toSet()
              .length;
          _patientCountCache[therapistId] = patientCount;

          return TherapistDashboardHeader(
            generatedAt: DateTime.now(),
            upcomingWeek: _buildUpcomingWeek(weekSessions),
            pendingRequests: _buildScheduleItems(
              pendingSessions.take(6).toList(),
              usersById,
            ),
            todayConfirmedSessions: _buildScheduleItems(
              todaySessions,
              usersById,
            ),
            scheduleItems: _buildScheduleItems(weekSessions, usersById),
            patientCount: patientCount,
          );
        });
  }

  Future<int> getPatientCount(String therapistId) async {
    final cached = _patientCountCache[therapistId];
    if (cached != null) {
      return cached;
    }

    final snapshot = await _therapistAppointmentsQuery(therapistId).get();
    final userIds = snapshot.docs
        .map((doc) => doc.data()['userId'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .length;
    _patientCountCache[therapistId] = userIds;
    return userIds;
  }

  void invalidatePatientCount(String therapistId) {
    _patientCountCache.remove(therapistId);
  }

  /// Loads patient summaries by fetching all appointments for the therapist
  /// (uses single-field index on therapistId) and processing in memory.
  Future<TherapistPageResult<TherapistPatientSummary>> loadPatientSummariesPage(
    String therapistId, {
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor,
    int pageSize = 16,
  }) async {
    final snapshot = await _therapistAppointmentsQuery(therapistId).get();
    final allSessions = snapshot.docs
        .map((doc) => SessionModel.fromMap(doc.data(), doc.id))
        .toList();

    final sessionsByUserId = <String, List<SessionModel>>{};
    for (final session in allSessions) {
      if (session.userId.isEmpty) {
        continue;
      }
      sessionsByUserId
          .putIfAbsent(session.userId, () => <SessionModel>[])
          .add(session);
    }

    final userIds =
        sessionsByUserId.keys.where((id) => id.isNotEmpty).toList();
    final usersById = await _fetchUsersByIds(userIds, forceRefresh: true);
    final users =
        userIds.map((id) => usersById[id]).whereType<AppUser>().toList();
    final moodsByUserId = await _fetchRecentMoodLookups(users, therapistId);
    final items = _buildPatientSummaries(
      users: users,
      sessions: allSessions,
      moodsByUserId: moodsByUserId,
      therapistId: therapistId,
    );

    return TherapistPageResult<TherapistPatientSummary>(
      items: items.take(pageSize).toList(),
      hasMore: items.length > pageSize,
      nextCursor: null,
    );
  }

  /// Loads schedule items by fetching all appointments for the therapist
  /// and filtering by view/status in memory.
  Future<TherapistPageResult<TherapistScheduleItem>> loadSchedulePage(
    String therapistId, {
    required TherapistScheduleView view,
    required TherapistScheduleStatusFilter statusFilter,
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor,
    int pageSize = 16,
  }) async {
    final snapshot = await _therapistAppointmentsQuery(therapistId).get();
    final allSessions = snapshot.docs
        .map((doc) => SessionModel.fromMap(doc.data(), doc.id))
        .toList();

    final filtered = allSessions
        .where((session) => _matchesScheduleFilters(
              session,
              view: view,
              statusFilter: statusFilter,
            ))
        .toList();

    // Sort based on view
    if (view == TherapistScheduleView.past) {
      filtered.sort(
          (a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    } else {
      filtered.sort(
          (a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    }

    final userIds = filtered
        .map((session) => session.userId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final usersById = await _fetchUsersByIds(userIds);
    final items = _buildScheduleItems(filtered, usersById)
        .take(pageSize)
        .toList();

    return TherapistPageResult<TherapistScheduleItem>(
      items: items,
      hasMore: filtered.length > pageSize,
      nextCursor: null,
    );
  }

  bool _matchesScheduleFilters(
    SessionModel session, {
    required TherapistScheduleView view,
    required TherapistScheduleStatusFilter statusFilter,
  }) {
    final item = TherapistScheduleItem(
      session: session,
      patientName: session.userName ?? 'Patient',
      patientEmail: 'Patient email unavailable',
    );
    final now = DateTime.now();
    final startOfToday = _startOfDay(now);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    final inView = switch (view) {
      TherapistScheduleView.today =>
        !item.startsAt.isBefore(startOfToday) &&
            item.startsAt.isBefore(endOfToday),
      TherapistScheduleView.upcoming =>
        item.startsAt.isAfter(
              endOfToday.subtract(const Duration(milliseconds: 1)),
            ) &&
            !item.isPast,
      TherapistScheduleView.past => item.isPast,
    };

    if (!inView) {
      return false;
    }

    return switch (statusFilter) {
      TherapistScheduleStatusFilter.all => true,
      TherapistScheduleStatusFilter.pending =>
        item.status == AppointmentStatus.requested,
      TherapistScheduleStatusFilter.confirmed =>
        item.status == AppointmentStatus.confirmed,
      TherapistScheduleStatusFilter.completed =>
        item.status == AppointmentStatus.completed,
    };
  }

  Future<Map<String, AppUser>> _fetchUsersByIds(
    List<String> userIds, {
    bool forceRefresh = false,
  }) async {
    if (userIds.isEmpty) {
      return const <String, AppUser>{};
    }

    final users = <String, AppUser>{};
    final missingIds = <String>[];
    for (final userId in userIds) {
      final cached = forceRefresh ? null : _userCache[userId];
      if (cached != null) {
        users[userId] = cached;
      } else {
        missingIds.add(userId);
      }
    }

    for (var index = 0; index < missingIds.length; index += 30) {
      final batch = missingIds.sublist(
        index,
        index + 30 > missingIds.length ? missingIds.length : index + 30,
      );
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snapshot.docs) {
        final user = AppUser.fromMap(doc.data(), doc.id);
        users[doc.id] = user;
        _userCache[doc.id] = user;
      }
    }

    return users;
  }

  /// Watches patient session history using a simple therapistId filter
  /// and doing patient filtering and sorting in memory.
  Stream<List<SessionModel>> watchPatientSessionHistory(
    String therapistId,
    String patientId, {
    int resultLimit = 8,
  }) {
    return _therapistAppointmentsQuery(therapistId)
        .snapshots()
        .map((snapshot) {
          final sessions =
              snapshot.docs
                  .map((doc) => SessionModel.fromMap(doc.data(), doc.id))
                  .where((session) => session.userId == patientId)
                  .toList()
                ..sort((left, right) {
                  final leftDate = left.updatedAt ?? left.scheduledAt;
                  final rightDate = right.updatedAt ?? right.scheduledAt;
                  return rightDate.compareTo(leftDate);
                });

          if (sessions.length > resultLimit) {
            return sessions.take(resultLimit).toList();
          }
          return sessions;
        });
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchRecentMoodLookups(
    List<AppUser> users,
    String therapistId,
  ) async {
    final moods = <String, List<Map<String, dynamic>>>{};
    final consentingUsers = users
        .where((user) => user.consentedTherapists.contains(therapistId))
        .toList();

    for (final user in consentingUsers) {
      final cached = _recentMoodCache[user.uid];
      if (cached != null) {
        moods[user.uid] = cached;
        continue;
      }

      final snapshot = await _firestore
          .collection('moods')
          .where('userId', isEqualTo: user.uid)
          .get();
      final entries = _normalizeMoodEntries(
        snapshot.docs.map((doc) => doc.data()),
        limit: 3,
      );
      moods[user.uid] = entries;
      _recentMoodCache[user.uid] = entries;
    }

    return moods;
  }

  TherapistMoodInsightTone _deriveMoodTone(List<Map<String, dynamic>> moods) {
    if (moods.isEmpty) {
      return TherapistMoodInsightTone.privateData;
    }

    final latestMood = (_coerceMoodString(moods.first['mood']) ?? '')
        .trim()
        .toLowerCase();
    final latestIntensity = (moods.first['intensity'] as num?)?.toInt() ?? 5;

    if (latestMood == 'happy' || latestMood == 'calm') {
      return TherapistMoodInsightTone.uplifting;
    }
    if (latestMood == 'sad' ||
        latestMood == 'anxious' ||
        latestMood == 'angry' ||
        latestMood == 'stressed') {
      return latestIntensity >= 7
          ? TherapistMoodInsightTone.watchful
          : TherapistMoodInsightTone.steady;
    }
    return TherapistMoodInsightTone.neutral;
  }

  String _deriveMoodLabel(
    TherapistMoodInsightTone tone,
    List<Map<String, dynamic>> moods,
  ) {
    if (moods.isEmpty) {
      return 'Private';
    }
    switch (tone) {
      case TherapistMoodInsightTone.uplifting:
        return 'Steady';
      case TherapistMoodInsightTone.watchful:
        return 'Check-in';
      case TherapistMoodInsightTone.privateData:
        return 'Private';
      case TherapistMoodInsightTone.neutral:
      case TherapistMoodInsightTone.steady:
        return 'Observed';
    }
  }

  String _deriveMoodDetail(
    TherapistMoodInsightTone tone,
    List<Map<String, dynamic>> moods,
  ) {
    if (moods.isEmpty) {
      return 'Mood history stays private until the patient shares it for care.';
    }

    final latestMood = (_coerceMoodString(moods.first['mood']) ?? 'recent')
        .trim()
        .toLowerCase();
    final latestIntensity = (moods.first['intensity'] as num?)?.toInt() ?? 5;
    final formattedMood = latestMood.isEmpty
        ? 'Recent mood'
        : '${latestMood[0].toUpperCase()}${latestMood.substring(1)}';

    switch (tone) {
      case TherapistMoodInsightTone.uplifting:
        return 'Recent shared logs suggest a calmer, more stable tone.';
      case TherapistMoodInsightTone.watchful:
        return 'Recent shared logs suggest extra care may help in the next session.';
      case TherapistMoodInsightTone.privateData:
        return 'Mood history stays private until the patient shares it for care.';
      case TherapistMoodInsightTone.neutral:
      case TherapistMoodInsightTone.steady:
        return '$formattedMood logged recently at intensity $latestIntensity/10.';
    }
  }

  String _relationshipLabel(List<SessionModel> sessions) {
    if (sessions.any(
      (session) => session.status == AppointmentStatus.confirmed,
    )) {
      return 'Active care';
    }
    if (sessions.any(
      (session) => session.status == AppointmentStatus.completed,
    )) {
      return 'Returning patient';
    }
    if (sessions.any(
      (session) => session.status == AppointmentStatus.requested,
    )) {
      return 'New request';
    }
    return 'Patient record';
  }

  List<TherapistScheduleItem> _buildScheduleItems(
    List<SessionModel> sessions,
    Map<String, AppUser> usersById,
  ) {
    final sorted = List<SessionModel>.from(sessions)
      ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
    return sorted.map((session) {
      final user = usersById[session.userId];
      return TherapistScheduleItem(
        session: session,
        user: user,
        patientName: user?.name ?? session.userName ?? 'Patient',
        patientEmail: user?.email ?? 'Patient email unavailable',
      );
    }).toList();
  }

  List<TherapistPatientSummary> _buildPatientSummaries({
    required List<AppUser> users,
    required List<SessionModel> sessions,
    required Map<String, List<Map<String, dynamic>>> moodsByUserId,
    required String therapistId,
  }) {
    final summaries = <TherapistPatientSummary>[];
    for (final user in users) {
      final userSessions =
          sessions.where((session) => session.userId == user.uid).toList()
            ..sort((left, right) {
              final leftDate = left.updatedAt ?? left.scheduledAt;
              final rightDate = right.updatedAt ?? right.scheduledAt;
              return rightDate.compareTo(leftDate);
            });
      final latestSession = userSessions.isEmpty ? null : userSessions.first;
      final sharedMoods = moodsByUserId[user.uid] ?? const [];
      final hasConsent = user.consentedTherapists.contains(therapistId);
      final moodTone = hasConsent
          ? _deriveMoodTone(sharedMoods)
          : TherapistMoodInsightTone.privateData;

      summaries.add(
        TherapistPatientSummary(
          user: user,
          hasConsent: hasConsent,
          lastInteractionAt:
              latestSession?.updatedAt ?? latestSession?.scheduledAt,
          latestStatus: latestSession?.status,
          moodTone: moodTone,
          relationshipLabel: _relationshipLabel(userSessions),
          moodSummaryLabel: _deriveMoodLabel(moodTone, sharedMoods),
          moodSummaryDetail: _deriveMoodDetail(moodTone, sharedMoods),
          latestMood: sharedMoods.isEmpty
              ? null
              : _coerceMoodString(sharedMoods.first['mood']),
          latestMoodIntensity: sharedMoods.isEmpty
              ? null
              : (sharedMoods.first['intensity'] as num?)?.toInt(),
        ),
      );
    }

    summaries.sort((left, right) {
      final leftDate =
          left.lastInteractionAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          right.lastInteractionAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });
    return summaries;
  }

  List<TherapistDayOverview> _buildUpcomingWeek(List<SessionModel> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List<TherapistDayOverview>.generate(7, (index) {
      final date = today.add(Duration(days: index));
      final daySessions = sessions.where((session) {
        final scheduled = session.scheduledAt;
        return scheduled.year == date.year &&
            scheduled.month == date.month &&
            scheduled.day == date.day;
      }).toList();
      return TherapistDayOverview(
        date: date,
        totalCount: daySessions.length,
        confirmedCount: daySessions
            .where((session) => session.status == AppointmentStatus.confirmed)
            .length,
        pendingCount: daySessions
            .where((session) => session.status == AppointmentStatus.requested)
            .length,
      );
    });
  }

  Future<AppUser?> getUserById(String userId) async {
    if (userId.isEmpty) {
      return null;
    }

    final cached = _userCache[userId];
    if (cached != null) {
      return cached;
    }

    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) {
      return null;
    }
    final user = AppUser.fromMap(doc.data()!, doc.id);
    _userCache[userId] = user;
    return user;
  }

  Stream<TherapistProfile?> getTherapistProfile(String therapistId) {
    if (therapistId.isEmpty) {
      return const Stream<TherapistProfile?>.empty();
    }
    return _firestore
        .collection('therapists')
        .doc(therapistId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? TherapistProfile.fromMap(snapshot.data()!, snapshot.id)
              : null,
        );
  }

  Stream<List<Map<String, dynamic>>> getPatientRecentMoods(String patientId) {
    return _firestore
        .collection('moods')
        .where('userId', isEqualTo: patientId)
        .snapshots()
        .map(
          (snapshot) => _normalizeMoodEntries(
            snapshot.docs.map((doc) => doc.data()),
            limit: 12,
          ),
        );
  }

  List<Map<String, dynamic>> _normalizeMoodEntries(
    Iterable<Map<String, dynamic>> rawEntries, {
    int? limit,
  }) {
    final normalized = rawEntries.map((entry) {
      final data = Map<String, dynamic>.from(entry);
      data['mood'] = _coerceMoodString(data['mood']);
      data['note'] = _coerceMoodString(data['note']) ?? '';
      data['resolvedAt'] = _resolveMoodDate(data);
      return data;
    }).toList();

    normalized.sort((left, right) {
      final leftDate =
          (left['resolvedAt'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          (right['resolvedAt'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });

    if (limit != null && normalized.length > limit) {
      return normalized.take(limit).toList();
    }
    return normalized;
  }

  DateTime? _resolveMoodDate(Map<String, dynamic> data) {
    for (final field in const ['selectedDate', 'createdAt', 'timestamp']) {
      final value = data[field];
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  String? _coerceMoodString(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }
}
