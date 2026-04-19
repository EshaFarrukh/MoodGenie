import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodgenie/src/auth/models/auth_models.dart';
import 'package:moodgenie/src/auth/models/user_model.dart';
import 'package:moodgenie/src/auth/repositories/auth_repository.dart';
import 'package:moodgenie/src/auth/services/auth_service.dart';
import 'package:moodgenie/src/auth/usecases/auth_usecases.dart';
import 'package:moodgenie/src/auth/usecases/user_signup_usecase.dart';

void main() {
  group('AuthService', () {
    late FakeAuthRepository repository;
    late AuthService authService;

    setUp(() {
      repository = FakeAuthRepository();
      authService = AuthService(
        signUpTherapistUseCase: SignUpTherapistUseCase(repository),
        signUpUserUseCase: SignUpUserUseCase(repository),
        signInUseCase: SignInUseCase(repository),
        signOutUseCase: SignOutUseCase(repository),
        getCurrentUserUseCase: GetCurrentUserUseCase(repository),
        repository: repository,
      );
    });

    tearDown(() {
      authService.dispose();
      repository.dispose();
    });

    test('signIn authenticates with a loaded user profile', () async {
      repository.profileToReturn = _buildUser(
        uid: 'user-1',
        email: 'user@example.com',
        role: UserRole.user,
      );

      await authService.signIn(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(authService.state.status, AuthStatus.authenticated);
      expect(authService.currentUser?.uid, 'user-1');
      expect(authService.currentUser?.role, UserRole.user);
      expect(authService.error, isNull);
    });

    test(
      'signIn recovers a missing profile through ensureCurrentUserProfile',
      () async {
        repository.simulateMissingProfile = true;
        repository.recoveredProfile = _buildUser(
          uid: 'legacy-user',
          email: 'legacy@example.com',
          role: UserRole.user,
        );

        await authService.signIn(
          email: 'legacy@example.com',
          password: 'password123',
        );

        expect(authService.state.status, AuthStatus.authenticated);
        expect(authService.currentUser?.uid, 'legacy-user');
        expect(repository.ensureCurrentUserProfileCalls, 1);
      },
    );

    test(
      'signUpTherapist returns to unauthenticated state with login prompt',
      () async {
        final result = await authService.signUpTherapist(
          email: 'therapist@example.com',
          password: 'password123',
          name: 'Dr Therapist',
          professionalTitle: 'Licensed Clinical Psychologist',
          licenseNumber: 'LCP-44512',
          licenseIssuingAuthority: 'Pakistan Psychological Council',
          licenseRegion: 'Pakistan',
          licenseExpiresAt: DateTime(2027, 12, 31),
          credentialEvidenceSummary: 'Registry reference 44512',
        );

        expect(result, isNotNull);
        expect(result?.email, 'therapist@example.com');
        expect(authService.state.status, AuthStatus.unauthenticated);
        expect(authService.currentUser, isNull);
        expect(repository.ensureCurrentUserProfileCalls, 1);
        expect(repository.signOutCalls, 1);
      },
    );

    test(
      'signInWithGoogle authenticates when the repository succeeds',
      () async {
        repository.googleSignInAvailable = true;
        repository.googleProfile = _buildUser(
          uid: 'google-user',
          email: 'google@example.com',
          role: UserRole.user,
          name: 'Google User',
        );

        await authService.signInWithGoogle();

        expect(authService.state.status, AuthStatus.authenticated);
        expect(authService.currentUser?.uid, 'google-user');
        expect(authService.currentUser?.email, 'google@example.com');
        expect(authService.error, isNull);
      },
    );

    test('signInWithGoogle surfaces repository configuration errors', () async {
      repository.googleSignInAvailable = true;
      repository.googleFailure = const UnknownFailure(
        'Google Sign-In is not fully configured for iOS yet.',
      );

      await authService.signInWithGoogle();

      expect(authService.state.status, AuthStatus.unauthenticated);
      expect(authService.currentUser, isNull);
      expect(
        authService.error,
        'Google Sign-In is not fully configured for iOS yet.',
      );
    });

    test('stream null event moves state to unauthenticated', () async {
      repository.emitSignedOut();
      await Future<void>.delayed(Duration.zero);

      expect(authService.state.status, AuthStatus.unauthenticated);
      expect(authService.currentUser, isNull);
    });
  });
}

class FakeAuthRepository implements AuthRepository {
  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();

  AppUser? profileToReturn;
  AppUser? recoveredProfile;
  AppUser? googleProfile;
  bool simulateMissingProfile = false;
  bool googleSignInAvailable = false;
  AuthFailure? googleFailure;
  int ensureCurrentUserProfileCalls = 0;
  int signOutCalls = 0;
  bool _signedIn = false;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  bool get isGoogleSignInAvailable => googleSignInAvailable;

  @override
  Future<AppUser?> getCurrentUser() async {
    if (!_signedIn || simulateMissingProfile) {
      return null;
    }

    return profileToReturn;
  }

  @override
  Future<AppUser> ensureCurrentUserProfile({
    UserRole? roleHint,
    String? nameHint,
  }) async {
    ensureCurrentUserProfileCalls += 1;

    final profile =
        recoveredProfile ??
        _buildUser(
          uid: profileToReturn?.uid ?? 'generated-user',
          email: profileToReturn?.email ?? 'generated@example.com',
          role: roleHint ?? UserRole.user,
          name: nameHint,
        );

    profileToReturn = profile;
    simulateMissingProfile = false;
    return profile;
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _signedIn = true;
    profileToReturn ??= _buildUser(
      uid: 'signed-in-user',
      email: email,
      role: UserRole.user,
    );
  }

  @override
  Future<void> signUpWithEmailAndPassword(
    String email,
    String password, {
    required UserRole role,
    String? name,
    String? therapistProfessionalTitle,
    String? therapistLicenseNumber,
    String? therapistLicenseIssuingAuthority,
    String? therapistLicenseRegion,
    DateTime? therapistLicenseExpiresAt,
    String? therapistCredentialEvidenceSummary,
  }) async {
    _signedIn = true;
    profileToReturn = _buildUser(
      uid: role == UserRole.therapist ? 'therapist-user' : 'signed-up-user',
      email: email,
      role: role,
      name: name,
    );
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    _signedIn = false;
    profileToReturn = null;
  }

  @override
  Future<void> signInWithGoogle() async {
    if (googleFailure != null) {
      throw googleFailure!;
    }

    _signedIn = true;
    profileToReturn =
        googleProfile ??
        _buildUser(
          uid: 'google-user',
          email: 'google@example.com',
          role: UserRole.user,
          name: 'Google User',
        );
  }

  @override
  Future<void> updateLastLoginAt(String uid) async {}

  void emitSignedOut() {
    _signedIn = false;
    profileToReturn = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

AppUser _buildUser({
  required String uid,
  required String email,
  required UserRole role,
  String? name,
}) {
  return AppUser(
    uid: uid,
    email: email,
    name: name,
    role: role,
    consentAccepted: false,
    createdAt: DateTime(2026, 1, 1),
    lastLoginAt: DateTime(2026, 1, 1),
  );
}
