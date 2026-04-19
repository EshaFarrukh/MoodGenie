import 'package:flutter/material.dart';

import 'backend_api_client.dart';

class BookableSlot {
  const BookableSlot({
    required this.slotId,
    required this.startAt,
    required this.endAt,
    required this.dateKey,
    required this.timezone,
    required this.status,
  });

  factory BookableSlot.fromJson(Map<String, dynamic> map) {
    return BookableSlot(
      slotId: map['slotId'] as String? ?? '',
      startAt: DateTime.parse(map['startAt'] as String).toLocal(),
      endAt: DateTime.parse(map['endAt'] as String).toLocal(),
      dateKey: map['dateKey'] as String? ?? '',
      timezone: map['timezone'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
    );
  }

  final String slotId;
  final DateTime startAt;
  final DateTime endAt;
  final String dateKey;
  final String timezone;
  final String status;

  TimeOfDay get startTimeOfDay =>
      TimeOfDay(hour: startAt.hour, minute: startAt.minute);
}

class TherapistAvailabilityRuleDto {
  const TherapistAvailabilityRuleDto({
    required this.weekday,
    required this.enabled,
    this.startTime,
    this.endTime,
  });

  factory TherapistAvailabilityRuleDto.fromJson(Map<String, dynamic> map) {
    return TherapistAvailabilityRuleDto(
      weekday: (map['weekday'] as num?)?.toInt() ?? 1,
      enabled: map['enabled'] != false,
      startTime: map['startTime'] as String?,
      endTime: map['endTime'] as String?,
    );
  }

  final int weekday;
  final bool enabled;
  final String? startTime;
  final String? endTime;

  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'enabled': enabled,
    'startTime': startTime,
    'endTime': endTime,
  };
}

class TherapistBlockedDateDto {
  const TherapistBlockedDateDto({
    required this.dateKey,
    this.note,
    this.blocked = true,
  });

  factory TherapistBlockedDateDto.fromJson(Map<String, dynamic> map) {
    return TherapistBlockedDateDto(
      dateKey: map['dateKey'] as String? ?? '',
      note: map['note'] as String?,
      blocked: map['blocked'] != false,
    );
  }

  final String dateKey;
  final String? note;
  final bool blocked;

  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'note': note,
    'blocked': blocked,
  };
}

class TherapistAvailabilitySnapshot {
  const TherapistAvailabilitySnapshot({
    required this.timezone,
    required this.acceptingNewPatients,
    required this.sessionDurationMinutes,
    required this.bufferMinutes,
    required this.weeklyRules,
    required this.blockedDates,
    required this.slots,
    this.dateKey,
    this.nextAvailableAt,
  });

  factory TherapistAvailabilitySnapshot.fromJson(Map<String, dynamic> map) {
    final slotEntries = map['slots'];
    final weeklyRules = map['weeklyRules'];
    final blockedDates = map['blockedDates'];
    final nextAvailableAtRaw = map['nextAvailableAt'];

    return TherapistAvailabilitySnapshot(
      timezone: map['timezone'] as String? ?? 'Asia/Karachi',
      acceptingNewPatients: map['acceptingNewPatients'] != false,
      sessionDurationMinutes:
          (map['sessionDurationMinutes'] as num?)?.toInt() ?? 60,
      bufferMinutes: (map['bufferMinutes'] as num?)?.toInt() ?? 15,
      dateKey: map['dateKey'] as String?,
      nextAvailableAt:
          nextAvailableAtRaw is String && nextAvailableAtRaw.isNotEmpty
          ? DateTime.parse(nextAvailableAtRaw).toLocal()
          : null,
      weeklyRules: weeklyRules is List
          ? weeklyRules
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .map(TherapistAvailabilityRuleDto.fromJson)
                .toList()
          : const <TherapistAvailabilityRuleDto>[],
      blockedDates: blockedDates is List
          ? blockedDates
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .map(TherapistBlockedDateDto.fromJson)
                .toList()
          : const <TherapistBlockedDateDto>[],
      slots: slotEntries is List
          ? slotEntries
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .map(BookableSlot.fromJson)
                .toList()
          : const <BookableSlot>[],
    );
  }

  final String timezone;
  final bool acceptingNewPatients;
  final int sessionDurationMinutes;
  final int bufferMinutes;
  final String? dateKey;
  final DateTime? nextAvailableAt;
  final List<TherapistAvailabilityRuleDto> weeklyRules;
  final List<TherapistBlockedDateDto> blockedDates;
  final List<BookableSlot> slots;
}

class TherapistBookingService {
  TherapistBookingService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  static TherapistAvailabilitySnapshot? _cachedMyAvailability;

  static String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  Future<TherapistAvailabilitySnapshot> fetchPublicAvailability(
    String therapistId, {
    required DateTime date,
  }) async {
    final response = await _apiClient.getJson(
      '/api/therapists/$therapistId/availability?date=${_dateKey(date)}',
    );
    return TherapistAvailabilitySnapshot.fromJson(response);
  }

  TherapistAvailabilitySnapshot? get cachedMyAvailability =>
      _cachedMyAvailability;

  void cacheMyAvailability(TherapistAvailabilitySnapshot snapshot) {
    _cachedMyAvailability = snapshot;
  }

  Future<TherapistAvailabilitySnapshot> fetchMyAvailability({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedMyAvailability != null) {
      return _cachedMyAvailability!;
    }
    final response = await _apiClient.getJson(
      '/api/therapists/me/availability',
    );
    final snapshot = TherapistAvailabilitySnapshot.fromJson(response);
    _cachedMyAvailability = snapshot;
    return snapshot;
  }

  Future<TherapistAvailabilitySnapshot> saveMyAvailability({
    required String timezone,
    required bool acceptingNewPatients,
    required int sessionDurationMinutes,
    required int bufferMinutes,
    required List<TherapistAvailabilityRuleDto> weeklyRules,
    required List<TherapistBlockedDateDto> blockedDates,
  }) async {
    final response = await _apiClient.postJson(
      '/api/therapists/me/availability',
      body: {
        'timezone': timezone,
        'acceptingNewPatients': acceptingNewPatients,
        'sessionDurationMinutes': sessionDurationMinutes,
        'bufferMinutes': bufferMinutes,
        'weeklyRules': weeklyRules.map((rule) => rule.toJson()).toList(),
        'blockedDates': blockedDates.map((date) => date.toJson()).toList(),
      },
      timeout: const Duration(seconds: 20),
    );
    final snapshot = TherapistAvailabilitySnapshot.fromJson(response);
    _cachedMyAvailability = snapshot;
    return snapshot;
  }

  Future<String> requestAppointment({
    required String therapistId,
    required String slotId,
    required bool consentGiven,
    String? notes,
  }) async {
    final response = await _apiClient.postJson(
      '/api/therapists/$therapistId/appointments/request',
      body: {'slotId': slotId, 'consentGiven': consentGiven, 'notes': notes},
      timeout: const Duration(seconds: 20),
    );

    return response['appointmentId'] as String? ?? '';
  }
}
