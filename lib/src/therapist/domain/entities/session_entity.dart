import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for session status
enum SessionStatus {
  requested,
  accepted,
  rejected,
  completed,
  cancelled,
  noShow;

  String get displayName {
    switch (this) {
      case SessionStatus.requested:
        return 'Requested';
      case SessionStatus.accepted:
        return 'Accepted';
      case SessionStatus.rejected:
        return 'Rejected';
      case SessionStatus.completed:
        return 'Completed';
      case SessionStatus.cancelled:
        return 'Cancelled';
      case SessionStatus.noShow:
        return 'No Show';
    }
  }

  static SessionStatus fromString(String status) {
    return SessionStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => SessionStatus.requested,
    );
  }
}

/// Domain entity representing a therapy session
class SessionEntity {
  final String sessionId;
  final String userId;
  final String therapistId;
  final DateTime scheduledAt;
  final SessionStatus status;
  final String? meetingRoomId;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SessionEntity({
    required this.sessionId,
    required this.userId,
    required this.therapistId,
    required this.scheduledAt,
    required this.status,
    this.meetingRoomId,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Creates entity from Firestore document
  factory SessionEntity.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    return SessionEntity(
      sessionId: doc.id,
      userId: data['userId'] ?? '',
      therapistId: data['therapistId'] ?? '',
      scheduledAt: (data['scheduledAt'] as Timestamp).toDate(),
      status: SessionStatus.fromString(data['status'] ?? 'requested'),
      meetingRoomId: data['meetingRoomId'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Converts entity to Firestore document format
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'therapistId': therapistId,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'status': status.name,
      'meetingRoomId': meetingRoomId,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Creates a copy with updated fields
  SessionEntity copyWith({
    String? sessionId,
    String? userId,
    String? therapistId,
    DateTime? scheduledAt,
    SessionStatus? status,
    String? meetingRoomId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionEntity(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      therapistId: therapistId ?? this.therapistId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      meetingRoomId: meetingRoomId ?? this.meetingRoomId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Validates session entity
  List<String> validate() {
    final errors = <String>[];

    if (userId.trim().isEmpty) {
      errors.add('User ID cannot be empty');
    }

    if (therapistId.trim().isEmpty) {
      errors.add('Therapist ID cannot be empty');
    }

    if (scheduledAt.isBefore(DateTime.now().subtract(const Duration(minutes: 15)))) {
      errors.add('Session cannot be scheduled in the past');
    }

    // Validate business hours (9 AM to 6 PM)
    final hour = scheduledAt.hour;
    if (hour < 9 || hour >= 18) {
      errors.add('Sessions must be scheduled between 9 AM and 6 PM');
    }

    // Validate weekdays only
    final weekday = scheduledAt.weekday;
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      errors.add('Sessions can only be scheduled on weekdays');
    }

    if (notes != null && notes!.length > 500) {
      errors.add('Notes cannot exceed 500 characters');
    }

    return errors;
  }

  /// Checks if the session can be cancelled
  bool canBeCancelled() {
    return status == SessionStatus.requested ||
           status == SessionStatus.accepted;
  }

  /// Checks if the session can be accepted
  bool canBeAccepted() {
    return status == SessionStatus.requested;
  }

  /// Checks if the session can be rejected
  bool canBeRejected() {
    return status == SessionStatus.requested;
  }

  /// Checks if the session can be completed
  bool canBeCompleted() {
    return status == SessionStatus.accepted &&
           DateTime.now().isAfter(scheduledAt);
  }

  /// Gets the duration until the session starts
  Duration get timeUntilSession {
    return scheduledAt.difference(DateTime.now());
  }

  /// Checks if the session is upcoming (within next 24 hours)
  bool get isUpcoming {
    final now = DateTime.now();
    final difference = scheduledAt.difference(now);
    return difference.inHours <= 24 && difference.inMinutes > 0;
  }

  /// Checks if the session is overdue (should have been completed)
  bool get isOverdue {
    return status == SessionStatus.accepted &&
           DateTime.now().isAfter(scheduledAt.add(const Duration(hours: 1)));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionEntity &&
        other.sessionId == sessionId &&
        other.userId == userId &&
        other.therapistId == therapistId &&
        other.scheduledAt == scheduledAt &&
        other.status == status;
  }

  @override
  int get hashCode {
    return sessionId.hashCode ^
        userId.hashCode ^
        therapistId.hashCode ^
        scheduledAt.hashCode ^
        status.hashCode;
  }

  @override
  String toString() {
    return 'SessionEntity(sessionId: $sessionId, userId: $userId, therapistId: $therapistId, scheduledAt: $scheduledAt, status: ${status.displayName})';
  }
}
