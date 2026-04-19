import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus {
  requested('requested', 'Pending'),
  confirmed('confirmed', 'Confirmed'),
  rejected('rejected', 'Rejected'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  noShow('no_show', 'No Show');

  const AppointmentStatus(this.value, this.label);

  final String value;
  final String label;

  static AppointmentStatus fromRaw(String? rawStatus) {
    switch ((rawStatus ?? '').trim().toLowerCase()) {
      case 'pending':
      case 'requested':
        return AppointmentStatus.requested;
      case 'accepted':
      case 'confirmed':
        return AppointmentStatus.confirmed;
      case 'rejected':
        return AppointmentStatus.rejected;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
      case 'canceled':
        return AppointmentStatus.cancelled;
      case 'no_show':
      case 'noshow':
        return AppointmentStatus.noShow;
      default:
        return AppointmentStatus.requested;
    }
  }
}

class SessionModel {
  final String sessionId;
  final String userId;
  final String therapistId;
  final AppointmentStatus status;
  final DateTime scheduledAt;
  final DateTime? scheduledEndAt;
  final DateTime? updatedAt;
  final String? meetingRoomId;
  final String? userName;
  final String? therapistName;
  final String? decisionReason;
  final String? notes;
  final String? timezone;
  final String? slotId;

  const SessionModel({
    required this.sessionId,
    required this.userId,
    required this.therapistId,
    required this.status,
    required this.scheduledAt,
    this.scheduledEndAt,
    this.updatedAt,
    this.meetingRoomId,
    this.userName,
    this.therapistName,
    this.decisionReason,
    this.notes,
    this.timezone,
    this.slotId,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map, String id) {
    return SessionModel(
      sessionId: id,
      userId: _coerceString(map['userId']) ?? '',
      therapistId: _coerceString(map['therapistId']) ?? '',
      status: AppointmentStatus.fromRaw(_coerceString(map['status'])),
      scheduledAt: _coerceDateTime(map['scheduledAt']) ?? DateTime.now(),
      scheduledEndAt: _coerceDateTime(map['scheduledEndAt']),
      updatedAt: _coerceDateTime(map['updatedAt']),
      meetingRoomId: _coerceString(map['meetingRoomId']),
      userName: _coerceString(map['userName']),
      therapistName: _coerceString(map['therapistName']),
      decisionReason: _coerceString(map['decisionReason']),
      notes: _coerceString(map['notes']),
      timezone: _coerceString(map['timezone']),
      slotId: _coerceString(map['slotId']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'therapistId': therapistId,
      'status': status.value,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'scheduledEndAt': scheduledEndAt != null
          ? Timestamp.fromDate(scheduledEndAt!)
          : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'meetingRoomId': meetingRoomId,
      'userName': userName,
      'therapistName': therapistName,
      'decisionReason': decisionReason,
      'notes': notes,
      'timezone': timezone,
      'slotId': slotId,
    };
  }

  SessionModel copyWith({
    AppointmentStatus? status,
    DateTime? scheduledAt,
    DateTime? scheduledEndAt,
    DateTime? updatedAt,
    String? meetingRoomId,
    String? userName,
    String? therapistName,
    String? decisionReason,
    String? notes,
    String? timezone,
    String? slotId,
  }) {
    return SessionModel(
      sessionId: sessionId,
      userId: userId,
      therapistId: therapistId,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      scheduledEndAt: scheduledEndAt ?? this.scheduledEndAt,
      updatedAt: updatedAt ?? this.updatedAt,
      meetingRoomId: meetingRoomId ?? this.meetingRoomId,
      userName: userName ?? this.userName,
      therapistName: therapistName ?? this.therapistName,
      decisionReason: decisionReason ?? this.decisionReason,
      notes: notes ?? this.notes,
      timezone: timezone ?? this.timezone,
      slotId: slotId ?? this.slotId,
    );
  }
}

String? _coerceString(dynamic value) {
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

DateTime? _coerceDateTime(dynamic value) {
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
    return DateTime.tryParse(value);
  }
  return null;
}
