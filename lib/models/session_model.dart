import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String sessionId;
  final String userId;
  final String therapistId;
  final String status; // 'pending', 'accepted', 'completed', 'rejected'
  final DateTime scheduledAt;
  final String? meetingRoomId;

  const SessionModel({
    required this.sessionId,
    required this.userId,
    required this.therapistId,
    required this.status,
    required this.scheduledAt,
    this.meetingRoomId,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map, String id) {
    return SessionModel(
      sessionId: id,
      userId: map['userId'] ?? '',
      therapistId: map['therapistId'] ?? '',
      status: map['status'] ?? 'pending',
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      meetingRoomId: map['meetingRoomId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'therapistId': therapistId,
      'status': status,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'meetingRoomId': meetingRoomId,
    };
  }

  SessionModel copyWith({
    String? status,
    DateTime? scheduledAt,
    String? meetingRoomId,
  }) {
    return SessionModel(
      sessionId: sessionId,
      userId: userId,
      therapistId: therapistId,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      meetingRoomId: meetingRoomId ?? this.meetingRoomId,
    );
  }
}
