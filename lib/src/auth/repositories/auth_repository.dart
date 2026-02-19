import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/auth_models.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<AppUser?> getCurrentUser();
  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> signUpWithEmailAndPassword(String email, String password, {required UserRole role, String? name});
  Future<void> signOut();
  Future<void> updateLastLoginAt(String uid);
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await updateLastLoginAt(credential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> signUpWithEmailAndPassword(
    String email,
    String password, {
    required UserRole role,
    String? name,
  }) async {
    try {
      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw const ServerFailure();

      // Update display name if provided
      if (name != null && name.isNotEmpty) {
        await user.updateDisplayName(name);
      }

      final now = DateTime.now();

      // Create user document
      final userData = {
        'email': email,
        'name': name,
        'role': role.name,
        'consentAccepted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(user.uid).set(userData);

      // If therapist, create therapist profile
      if (role == UserRole.therapist) {
        final therapistData = {
          'userId': user.uid,
          'isApproved': false,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('therapists').doc(user.uid).set(therapistData);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
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
      case 'invalid-email':
        return const InvalidEmailFailure();
      case 'user-disabled':
        return const UserDisabledFailure();
      case 'network-request-failed':
        return const NetworkFailure();
      default:
        return UnknownFailure(e.message ?? 'An unknown error occurred');
    }
  }
}
