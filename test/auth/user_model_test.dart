import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodgenie/src/auth/models/user_model.dart';

void main() {
  group('TherapistProfile', () {
    test('parses expanded credential verification fields safely', () {
      final createdAt = DateTime(2026, 4, 1);
      final expiresAt = DateTime(2027, 1, 1);
      final verifiedAt = DateTime(2026, 4, 2);

      final profile = TherapistProfile.fromMap({
        'userId': 'therapist-1',
        'displayName': 'Dr. Noor',
        'professionalTitle': 'Clinical Psychologist',
        'isApproved': true,
        'acceptingNewPatients': false,
        'specialty': 'CBT',
        'bio': 'Trauma-informed support.',
        'yearsExperience': 8,
        'pricePerSession': 150,
        'rating': 4.9,
        'reviewStatus': 'approved',
        'accountStatus': 'active',
        'credentialVerificationStatus': 'verified',
        'licenseNumber': 'ABC-1234',
        'licenseIssuingAuthority': 'Psychology Board',
        'licenseRegion': 'CA',
        'licenseExpiresAt': Timestamp.fromDate(expiresAt),
        'credentialEvidenceSummary': 'License document reviewed.',
        'credentialVerifiedAt': Timestamp.fromDate(verifiedAt),
        'credentialVerifiedBy': 'admin-1',
        'verificationMethod': 'manual_document_review',
        'verificationReference': 'case-therapist-1',
        'createdAt': Timestamp.fromDate(createdAt),
      }, 'therapist-1');

      expect(profile.therapistId, 'therapist-1');
      expect(profile.userId, 'therapist-1');
      expect(profile.displayName, 'Dr. Noor');
      expect(profile.professionalTitle, 'Clinical Psychologist');
      expect(profile.isApproved, isTrue);
      expect(profile.acceptingNewPatients, isFalse);
      expect(profile.credentialVerificationStatus, 'verified');
      expect(profile.licenseNumber, 'ABC-1234');
      expect(profile.licenseExpiresAt, expiresAt);
      expect(profile.credentialVerifiedBy, 'admin-1');
      expect(profile.verificationMethod, 'manual_document_review');
      expect(profile.verificationReference, 'case-therapist-1');
      expect(profile.createdAt, createdAt);
    });

    test(
      'serializes expanded credential verification fields for Firestore',
      () {
        final profile = TherapistProfile(
          therapistId: 'therapist-1',
          userId: 'therapist-1',
          displayName: 'Dr. Noor',
          professionalTitle: 'Clinical Psychologist',
          isApproved: true,
          acceptingNewPatients: true,
          specialty: 'CBT',
          reviewStatus: 'approved',
          accountStatus: 'active',
          credentialVerificationStatus: 'verified',
          licenseNumber: 'ABC-1234',
          licenseIssuingAuthority: 'Psychology Board',
          licenseRegion: 'CA',
          licenseExpiresAt: DateTime(2027, 1, 1),
          credentialEvidenceSummary: 'Board certificate reviewed.',
          credentialVerifiedAt: DateTime(2026, 4, 2),
          credentialVerifiedBy: 'admin-1',
          verificationMethod: 'manual_document_review',
          verificationReference: 'case-therapist-1',
          createdAt: DateTime(2026, 4, 1),
        );

        final data = profile.toMap();
        expect(data['displayName'], 'Dr. Noor');
        expect(data['professionalTitle'], 'Clinical Psychologist');
        expect(data['credentialVerificationStatus'], 'verified');
        expect(data['licenseNumber'], 'ABC-1234');
        expect(data['verificationMethod'], 'manual_document_review');
        expect(data['verificationReference'], 'case-therapist-1');
        expect(data['createdAt'], isA<Timestamp>());
        expect(data['licenseExpiresAt'], isA<Timestamp>());
        expect(data['credentialVerifiedAt'], isA<Timestamp>());
      },
    );
  });
}
