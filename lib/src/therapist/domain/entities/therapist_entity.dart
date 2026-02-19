import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain entity representing a therapist in the system
class TherapistEntity {
  final String therapistId;
  final String userId;
  final String name;
  final String specialization;
  final int experienceYears;
  final List<AvailabilitySlotEntity> availabilitySlots;
  final double rating;
  final bool isApproved;
  final DateTime createdAt;

  const TherapistEntity({
    required this.therapistId,
    required this.userId,
    required this.name,
    required this.specialization,
    required this.experienceYears,
    required this.availabilitySlots,
    required this.rating,
    required this.isApproved,
    required this.createdAt,
  });

  /// Creates entity from Firestore document
  factory TherapistEntity.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Parse availability slots
    final slotsData = data['availabilitySlots'] as List<dynamic>? ?? [];
    final slots = slotsData
        .map((slot) => AvailabilitySlotEntity.fromMap(slot as Map<String, dynamic>))
        .toList();

    return TherapistEntity(
      therapistId: doc.id,
      userId: data['userId'] ?? doc.id,
      name: data['name'] ?? '',
      specialization: data['specialization'] ?? '',
      experienceYears: (data['experienceYears'] ?? 0) is int
          ? data['experienceYears']
          : int.tryParse(data['experienceYears']?.toString() ?? '0') ?? 0,
      availabilitySlots: slots,
      rating: (data['rating'] ?? 0.0) is double
          ? data['rating']
          : double.tryParse(data['rating']?.toString() ?? '0.0') ?? 0.0,
      isApproved: data['isApproved'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts entity to Firestore document format
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'specialization': specialization,
      'experienceYears': experienceYears,
      'availabilitySlots': availabilitySlots.map((slot) => slot.toMap()).toList(),
      'rating': rating,
      'isApproved': isApproved,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Creates a copy with updated fields
  TherapistEntity copyWith({
    String? therapistId,
    String? userId,
    String? name,
    String? specialization,
    int? experienceYears,
    List<AvailabilitySlotEntity>? availabilitySlots,
    double? rating,
    bool? isApproved,
    DateTime? createdAt,
  }) {
    return TherapistEntity(
      therapistId: therapistId ?? this.therapistId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      specialization: specialization ?? this.specialization,
      experienceYears: experienceYears ?? this.experienceYears,
      availabilitySlots: availabilitySlots ?? this.availabilitySlots,
      rating: rating ?? this.rating,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Validates therapist entity
  List<String> validate() {
    final errors = <String>[];

    if (name.trim().isEmpty) {
      errors.add('Name cannot be empty');
    }

    if (specialization.trim().isEmpty) {
      errors.add('Specialization cannot be empty');
    }

    if (experienceYears < 0) {
      errors.add('Experience years cannot be negative');
    }

    if (rating < 0.0 || rating > 5.0) {
      errors.add('Rating must be between 0.0 and 5.0');
    }

    // Validate availability slots
    for (final slot in availabilitySlots) {
      final slotErrors = slot.validate();
      errors.addAll(slotErrors);
    }

    return errors;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TherapistEntity &&
        other.therapistId == therapistId &&
        other.userId == userId &&
        other.name == name &&
        other.specialization == specialization &&
        other.experienceYears == experienceYears &&
        other.rating == rating &&
        other.isApproved == isApproved;
  }

  @override
  int get hashCode {
    return therapistId.hashCode ^
        userId.hashCode ^
        name.hashCode ^
        specialization.hashCode ^
        experienceYears.hashCode ^
        rating.hashCode ^
        isApproved.hashCode;
  }

  @override
  String toString() {
    return 'TherapistEntity(therapistId: $therapistId, name: $name, specialization: $specialization, isApproved: $isApproved)';
  }
}

/// Domain entity representing an availability time slot
class AvailabilitySlotEntity {
  final DateTime startAt;
  final DateTime endAt;
  final bool isBooked;

  const AvailabilitySlotEntity({
    required this.startAt,
    required this.endAt,
    this.isBooked = false,
  });

  /// Creates entity from map
  factory AvailabilitySlotEntity.fromMap(Map<String, dynamic> map) {
    return AvailabilitySlotEntity(
      startAt: (map['startAt'] as Timestamp).toDate(),
      endAt: (map['endAt'] as Timestamp).toDate(),
      isBooked: map['isBooked'] ?? false,
    );
  }

  /// Converts entity to map format
  Map<String, dynamic> toMap() {
    return {
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'isBooked': isBooked,
    };
  }

  /// Creates a copy with updated fields
  AvailabilitySlotEntity copyWith({
    DateTime? startAt,
    DateTime? endAt,
    bool? isBooked,
  }) {
    return AvailabilitySlotEntity(
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isBooked: isBooked ?? this.isBooked,
    );
  }

  /// Validates availability slot
  List<String> validate() {
    final errors = <String>[];

    if (startAt.isAfter(endAt)) {
      errors.add('Start time must be before end time');
    }

    if (startAt.isBefore(DateTime.now().subtract(const Duration(minutes: 30)))) {
      errors.add('Start time cannot be in the past');
    }

    final duration = endAt.difference(startAt);
    if (duration.inMinutes < 30) {
      errors.add('Slot duration must be at least 30 minutes');
    }

    if (duration.inHours > 4) {
      errors.add('Slot duration cannot exceed 4 hours');
    }

    return errors;
  }

  /// Checks if this slot overlaps with another slot
  bool overlapsWith(AvailabilitySlotEntity other) {
    return startAt.isBefore(other.endAt) && endAt.isAfter(other.startAt);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AvailabilitySlotEntity &&
        other.startAt == startAt &&
        other.endAt == endAt &&
        other.isBooked == isBooked;
  }

  @override
  int get hashCode {
    return startAt.hashCode ^ endAt.hashCode ^ isBooked.hashCode;
  }

  @override
  String toString() {
    return 'AvailabilitySlotEntity(startAt: $startAt, endAt: $endAt, isBooked: $isBooked)';
  }
}
