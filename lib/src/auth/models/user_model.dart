import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole { user, therapist, admin }

class AppUser {
  final String uid;
  final String email;
  final String? name;
  final UserRole role;
  final bool consentAccepted;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  const AppUser({
    required this.uid,
    required this.email,
    this.name,
    required this.role,
    required this.consentAccepted,
    required this.createdAt,
    required this.lastLoginAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'],
      role: UserRole.values.firstWhere(
        (role) => role.name == map['role'],
        orElse: () => UserRole.user,
      ),
      consentAccepted: map['consentAccepted'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'consentAccepted': consentAccepted,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
    };
  }

  AppUser copyWith({
    String? email,
    String? name,
    UserRole? role,
    bool? consentAccepted,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

class TherapistProfile {
  final String therapistId;
  final String userId;
  final bool isApproved;
  final String? specialty;
  final int? yearsExperience;
  final int? pricePerSession;
  final double? rating;
  final DateTime? nextAvailableAt;
  final DateTime createdAt;

  const TherapistProfile({
    required this.therapistId,
    required this.userId,
    required this.isApproved,
    this.specialty,
    this.yearsExperience,
    this.pricePerSession,
    this.rating,
    this.nextAvailableAt,
    required this.createdAt,
  });

  factory TherapistProfile.fromMap(Map<String, dynamic> map, String id) {
    return TherapistProfile(
      therapistId: id,
      userId: map['userId'] ?? id,
      isApproved: map['isApproved'] ?? false,
      specialty: map['specialty'],
      yearsExperience: map['yearsExperience'],
      pricePerSession: map['pricePerSession'],
      rating: map['rating']?.toDouble(),
      nextAvailableAt: (map['nextAvailableAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'isApproved': isApproved,
      'specialty': specialty,
      'yearsExperience': yearsExperience,
      'pricePerSession': pricePerSession,
      'rating': rating,
      'nextAvailableAt': nextAvailableAt != null ? Timestamp.fromDate(nextAvailableAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
