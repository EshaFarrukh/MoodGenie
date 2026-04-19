import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, therapist, admin }

String? _asTrimmedString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  final normalized = _asTrimmedString(value)?.toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'approved' ||
      normalized == 'verified' ||
      normalized == 'active';
}

bool? _asOptionalBool(dynamic value) {
  if (value == null) {
    return null;
  }
  return _asBool(value);
}

bool _resolveTherapistApproval(Map<String, dynamic> map) {
  final explicitApproval = map['isApproved'];
  if (explicitApproval != null) {
    return _asBool(explicitApproval);
  }

  final reviewStatus = _asTrimmedString(map['reviewStatus'])?.toLowerCase();
  final accountStatus = _asTrimmedString(map['accountStatus'])?.toLowerCase();
  final verificationStatus =
      _asTrimmedString(map['credentialVerificationStatus'])?.toLowerCase();

  return reviewStatus == 'approved' ||
      accountStatus == 'active' ||
      verificationStatus == 'verified';
}

class AppUser {
  final String uid;
  final String email;
  final String? name;
  final UserRole role;
  final bool consentAccepted; // App terms consent
  final List<String>
  consentedTherapists; // Therapist IDs allowed to view mood data
  final DateTime createdAt;
  final DateTime lastLoginAt;

  const AppUser({
    required this.uid,
    required this.email,
    this.name,
    required this.role,
    required this.consentAccepted,
    this.consentedTherapists = const [],
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
      consentedTherapists: List<String>.from(map['consentedTherapists'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt:
          (map['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'consentAccepted': consentAccepted,
      'consentedTherapists': consentedTherapists,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
    };
  }

  AppUser copyWith({
    String? email,
    String? name,
    UserRole? role,
    bool? consentAccepted,
    List<String>? consentedTherapists,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      consentedTherapists: consentedTherapists ?? this.consentedTherapists,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

class TherapistProfile {
  final String therapistId;
  final String userId;
  final String? displayName;
  final String? professionalTitle;
  final bool isApproved;
  final bool acceptingNewPatients;
  final String? specialty;
  final String? bio;
  final int? yearsExperience;
  final int? pricePerSession;
  final double? rating;
  final DateTime? nextAvailableAt;
  final String reviewStatus;
  final String accountStatus;
  final String credentialVerificationStatus;
  final String? licenseNumber;
  final String? licenseIssuingAuthority;
  final String? licenseRegion;
  final DateTime? licenseExpiresAt;
  final String? credentialEvidenceSummary;
  final DateTime? approvalRequestedAt;
  final DateTime? credentialSubmittedAt;
  final DateTime? credentialVerifiedAt;
  final String? credentialVerifiedBy;
  final String? verificationMethod;
  final String? verificationReference;
  final DateTime createdAt;

  const TherapistProfile({
    required this.therapistId,
    required this.userId,
    this.displayName,
    this.professionalTitle,
    required this.isApproved,
    required this.acceptingNewPatients,
    this.specialty,
    this.bio,
    this.yearsExperience,
    this.pricePerSession,
    this.rating,
    this.nextAvailableAt,
    this.reviewStatus = 'pending_review',
    this.accountStatus = 'pending_review',
    this.credentialVerificationStatus = 'pending_review',
    this.licenseNumber,
    this.licenseIssuingAuthority,
    this.licenseRegion,
    this.licenseExpiresAt,
    this.credentialEvidenceSummary,
    this.approvalRequestedAt,
    this.credentialSubmittedAt,
    this.credentialVerifiedAt,
    this.credentialVerifiedBy,
    this.verificationMethod,
    this.verificationReference,
    required this.createdAt,
  });

  factory TherapistProfile.fromMap(Map<String, dynamic> map, String id) {
    final reviewStatus = _asTrimmedString(map['reviewStatus']) ?? 'pending_review';
    final accountStatus =
        _asTrimmedString(map['accountStatus']) ?? 'pending_review';
    final credentialVerificationStatus =
        _asTrimmedString(map['credentialVerificationStatus']) ??
        'pending_review';

    return TherapistProfile(
      therapistId: id,
      userId: _asTrimmedString(map['userId']) ?? id,
      displayName: _asTrimmedString(map['displayName']) ?? _asTrimmedString(map['name']),
      professionalTitle: _asTrimmedString(map['professionalTitle']),
      isApproved: _resolveTherapistApproval(map),
      acceptingNewPatients: _asOptionalBool(map['acceptingNewPatients']) ?? true,
      specialty: _asTrimmedString(map['specialty']),
      bio: _asTrimmedString(map['bio']),
      yearsExperience: map['yearsExperience'],
      pricePerSession: map['pricePerSession'],
      rating: map['rating']?.toDouble(),
      nextAvailableAt: (map['nextAvailableAt'] as Timestamp?)?.toDate(),
      reviewStatus: reviewStatus,
      accountStatus: accountStatus,
      credentialVerificationStatus: credentialVerificationStatus,
      licenseNumber: _asTrimmedString(map['licenseNumber']),
      licenseIssuingAuthority: _asTrimmedString(map['licenseIssuingAuthority']),
      licenseRegion: _asTrimmedString(map['licenseRegion']),
      licenseExpiresAt: (map['licenseExpiresAt'] as Timestamp?)?.toDate(),
      credentialEvidenceSummary: _asTrimmedString(map['credentialEvidenceSummary']),
      approvalRequestedAt: (map['approvalRequestedAt'] as Timestamp?)?.toDate(),
      credentialSubmittedAt: (map['credentialSubmittedAt'] as Timestamp?)
          ?.toDate(),
      credentialVerifiedAt:
          (map['credentialVerifiedAt'] as Timestamp?)?.toDate() ??
          (map['verifiedAt'] as Timestamp?)?.toDate() ??
          (map['reviewedAt'] as Timestamp?)?.toDate(),
      credentialVerifiedBy:
          _asTrimmedString(map['credentialVerifiedBy']) ??
          _asTrimmedString(map['reviewedBy']),
      verificationMethod: _asTrimmedString(map['verificationMethod']),
      verificationReference: _asTrimmedString(map['verificationReference']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'professionalTitle': professionalTitle,
      'isApproved': isApproved,
      'acceptingNewPatients': acceptingNewPatients,
      'specialty': specialty,
      'bio': bio,
      'yearsExperience': yearsExperience,
      'pricePerSession': pricePerSession,
      'rating': rating,
      'nextAvailableAt': nextAvailableAt != null
          ? Timestamp.fromDate(nextAvailableAt!)
          : null,
      'reviewStatus': reviewStatus,
      'accountStatus': accountStatus,
      'credentialVerificationStatus': credentialVerificationStatus,
      'licenseNumber': licenseNumber,
      'licenseIssuingAuthority': licenseIssuingAuthority,
      'licenseRegion': licenseRegion,
      'licenseExpiresAt': licenseExpiresAt != null
          ? Timestamp.fromDate(licenseExpiresAt!)
          : null,
      'credentialEvidenceSummary': credentialEvidenceSummary,
      'approvalRequestedAt': approvalRequestedAt != null
          ? Timestamp.fromDate(approvalRequestedAt!)
          : null,
      'credentialSubmittedAt': credentialSubmittedAt != null
          ? Timestamp.fromDate(credentialSubmittedAt!)
          : null,
      'credentialVerifiedAt': credentialVerifiedAt != null
          ? Timestamp.fromDate(credentialVerifiedAt!)
          : null,
      'credentialVerifiedBy': credentialVerifiedBy,
      'verificationMethod': verificationMethod,
      'verificationReference': verificationReference,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
