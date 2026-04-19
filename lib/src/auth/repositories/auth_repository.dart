import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../models/auth_models.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<AppUser?> getCurrentUser();
  Future<AppUser> ensureCurrentUserProfile({
    UserRole? roleHint,
    String? nameHint,
  });
  Future<void> signInWithEmailAndPassword(String email, String password);
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
  });
  Future<void> signOut();
  Future<void> updateLastLoginAt(String uid);
  Future<void> signInWithGoogle();
  bool get isGoogleSignInAvailable;
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  bool get isGoogleSignInAvailable {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      return AppUser.fromMap(userDoc.data()!, user.uid);
    } catch (e) {
      throw ServerFailure();
    }
  }

  @override
  Future<AppUser> ensureCurrentUserProfile({
    UserRole? roleHint,
    String? nameHint,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const ServerFailure();
      }

      final userRef = _firestore.collection('users').doc(user.uid);
      final existingUserDoc = await userRef.get();
      if (existingUserDoc.exists) {
        return AppUser.fromMap(existingUserDoc.data()!, user.uid);
      }

      final therapistDoc = await _firestore
          .collection('therapists')
          .doc(user.uid)
          .get();
      final role =
          roleHint ??
          (therapistDoc.exists ? UserRole.therapist : UserRole.user);

      await userRef.set(
        _buildUserData(
          email: user.email ?? '',
          role: role,
          name: nameHint ?? user.displayName,
        ),
        SetOptions(merge: true),
      );

      if (role == UserRole.therapist && !therapistDoc.exists) {
        await _firestore
            .collection('therapists')
            .doc(user.uid)
            .set(_buildTherapistData(user.uid, nameHint ?? user.displayName));
      }

      final syncedUserDoc = await userRef.get();
      if (!syncedUserDoc.exists) {
        throw const ServerFailure();
      }

      return AppUser.fromMap(syncedUserDoc.data()!, user.uid);
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      if (kDebugMode) {
        debugPrint('Attempting email sign-in');
      }
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (kDebugMode) {
        debugPrint('Email sign-in completed');
      }

      if (credential.user != null) {
        await updateLastLoginAt(credential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('Email sign-in FirebaseAuthException: code=${e.code}');
      }
      throw _mapFirebaseAuthException(e);
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('Email sign-in FirebaseException: code=${e.code}');
      }
      throw _mapFirebaseException(e);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Email sign-in failed with ${e.runtimeType}');
      }
      throw UnknownFailure(e.toString());
    }
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
    User? user;
    bool userDocCreated = false;
    bool therapistDocCreated = false;

    try {
      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = credential.user;
      if (user == null) throw const ServerFailure();

      // Update display name if provided
      if (name != null && name.isNotEmpty) {
        await user.updateDisplayName(name);
      }

      // Create user document
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(_buildUserData(email: email, role: role, name: name));
      userDocCreated = true;

      // If therapist, create therapist profile
      if (role == UserRole.therapist) {
        await _firestore
            .collection('therapists')
            .doc(user.uid)
            .set(
              _buildTherapistData(
                user.uid,
                name,
                professionalTitle: therapistProfessionalTitle,
                licenseNumber: therapistLicenseNumber,
                licenseIssuingAuthority: therapistLicenseIssuingAuthority,
                licenseRegion: therapistLicenseRegion,
                licenseExpiresAt: therapistLicenseExpiresAt,
                credentialEvidenceSummary: therapistCredentialEvidenceSummary,
              ),
            );
        therapistDocCreated = true;
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('Sign-up FirebaseAuthException: code=${e.code}');
      }
      await _rollbackFailedSignUp(
        user: user,
        userDocCreated: userDocCreated,
        therapistDocCreated: therapistDocCreated,
      );
      throw _mapFirebaseAuthException(e);
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('Sign-up FirebaseException: code=${e.code}');
      }
      await _rollbackFailedSignUp(
        user: user,
        userDocCreated: userDocCreated,
        therapistDocCreated: therapistDocCreated,
      );
      throw _mapFirebaseException(e);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Sign-up failed with ${e.runtimeType}');
      }
      await _rollbackFailedSignUp(
        user: user,
        userDocCreated: userDocCreated,
        therapistDocCreated: therapistDocCreated,
      );
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        try {
          switch (defaultTargetPlatform) {
            case TargetPlatform.android:
            case TargetPlatform.iOS:
            case TargetPlatform.macOS:
              final googleSignIn = GoogleSignIn(
                scopes: const ['email'],
                clientId: _googleClientIdForCurrentPlatform(),
              );

              if (await googleSignIn.isSignedIn()) {
                await googleSignIn.signOut();
              }
              break;
            default:
              break;
          }
        } catch (_) {
          // Continue with Firebase sign-out even if the Google session cache
          // could not be cleared on this device.
        }
      }

      await _auth.signOut();
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> updateLastLoginAt(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't throw error for lastLoginAt update failure
      // Log error in production
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      if (!isGoogleSignInAvailable) {
        throw UnknownFailure(_googleConfigurationMessage());
      }

      if (kDebugMode) {
        debugPrint('Starting Google Sign-In');
      }

      if (kIsWeb) {
        final provider = GoogleAuthProvider()..addScope('email');
        final userCredential = await _auth.signInWithPopup(provider);
        final user = userCredential.user;
        if (user == null) {
          throw const ServerFailure();
        }

        await ensureCurrentUserProfile(
          roleHint: UserRole.user,
          nameHint: user.displayName,
        );
        await updateLastLoginAt(user.uid);
        return;
      }

      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: const ['email'],
        clientId: _googleClientIdForCurrentPlatform(),
      );

      GoogleSignInAccount? googleUser;
      try {
        googleUser = await googleSignIn.signIn();
      } on PlatformException catch (e) {
        if (kDebugMode) {
          debugPrint('Google Sign-In PlatformException: ${e.code}');
        }
        throw _mapGooglePlatformException(e);
      }

      if (googleUser == null) {
        throw const AuthCancelledFailure();
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw const UnknownFailure(
          'Google Sign-In did not return an ID token. Please check your Firebase Google provider setup.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw const ServerFailure();

      if (kDebugMode) {
        debugPrint('Google Sign-In completed');
      }
      await ensureCurrentUserProfile(
        roleHint: UserRole.user,
        nameHint: user.displayName,
      );
      await updateLastLoginAt(user.uid);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on PlatformException catch (e) {
      throw _mapGooglePlatformException(e);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw UnknownFailure(e.toString());
    }
  }

  Map<String, dynamic> _buildUserData({
    required String email,
    required UserRole role,
    String? name,
  }) {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'consentAccepted': false,
      'consentedTherapists': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _buildTherapistData(
    String uid,
    String? displayName, {
    String? professionalTitle,
    String? licenseNumber,
    String? licenseIssuingAuthority,
    String? licenseRegion,
    DateTime? licenseExpiresAt,
    String? credentialEvidenceSummary,
  }) {
    return {
      'userId': uid,
      'displayName': displayName,
      'professionalTitle': professionalTitle,
      'licenseNumber': licenseNumber,
      'licenseIssuingAuthority': licenseIssuingAuthority,
      'licenseRegion': licenseRegion,
      'licenseExpiresAt': licenseExpiresAt != null
          ? Timestamp.fromDate(licenseExpiresAt)
          : null,
      'credentialEvidenceSummary': credentialEvidenceSummary,
      'credentialSubmittedAt': FieldValue.serverTimestamp(),
      'credentialVerificationStatus': 'pending_review',
      'reviewStatus': 'pending_review',
      'accountStatus': 'pending_review',
      'acceptingNewPatients': true,
      'isApproved': false,
      'approvalRequestedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _rollbackFailedSignUp({
    required User? user,
    required bool userDocCreated,
    required bool therapistDocCreated,
  }) async {
    if (user == null) {
      return;
    }

    try {
      if (therapistDocCreated) {
        await _firestore.collection('therapists').doc(user.uid).delete();
      }

      if (userDocCreated) {
        await _firestore.collection('users').doc(user.uid).delete();
      }

      await user.delete();
    } catch (_) {
      // Best-effort rollback only.
    } finally {
      await _auth.signOut();
    }
  }

  String _googleConfigurationMessage() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Google Sign-In is not fully configured for Android yet. Enable the Google provider in Firebase Auth, add your Android SHA certificates, then download an updated google-services.json.';
      case TargetPlatform.iOS:
        return 'Google Sign-In is not fully configured for iOS yet. Download a fresh GoogleService-Info.plist with CLIENT_ID, then add the REVERSED_CLIENT_ID URL scheme to ios/Runner/Info.plist.';
      case TargetPlatform.macOS:
        return 'Google Sign-In is not fully configured for macOS yet. Download a fresh GoogleService-Info.plist, add the REVERSED_CLIENT_ID URL scheme, and enable the Google keychain entitlement.';
      default:
        return 'Google Sign-In is not configured for this platform yet.';
    }
  }

  String? _googleClientIdForCurrentPlatform() {
    final options = Firebase.app().options;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return options.iosClientId;
      case TargetPlatform.android:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return null;
    }
  }

  AuthFailure _mapGooglePlatformException(PlatformException e) {
    switch (e.code) {
      case GoogleSignIn.kSignInCanceledError:
        return const AuthCancelledFailure();
      case GoogleSignIn.kNetworkError:
        return const NetworkFailure();
      case GoogleSignIn.kSignInRequiredError:
      case GoogleSignIn.kSignInFailedError:
        return UnknownFailure(
          e.message ?? 'Google Sign-In failed. Please try again.',
        );
      default:
        return UnknownFailure(
          e.message ??
              'Google Sign-In failed. Please check your configuration.',
        );
    }
  }

  AuthFailure _mapFirebaseException(FirebaseException e) {
    // Handle FirebaseException (which may wrap auth errors)
    switch (e.code) {
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return const InvalidCredentialFailure();
      case 'network-request-failed':
        return const NetworkFailure();
      case 'too-many-requests':
        return const TooManyRequestsFailure();
      default:
        return UnknownFailure(e.message ?? 'An unknown error occurred');
    }
  }

  AuthFailure _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return const EmailAlreadyInUseFailure();
      case 'weak-password':
        return const WeakPasswordFailure();
      case 'user-not-found':
        return const UserNotFoundFailure();
      case 'wrong-password':
        return const WrongPasswordFailure();
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return const InvalidCredentialFailure();
      case 'invalid-email':
        return const InvalidEmailFailure();
      case 'user-disabled':
        return const UserDisabledFailure();
      case 'network-request-failed':
        return const NetworkFailure();
      case 'too-many-requests':
        return const TooManyRequestsFailure();
      default:
        return UnknownFailure(e.message ?? 'An unknown error occurred');
    }
  }
}
