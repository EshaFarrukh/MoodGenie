import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/auth_models.dart';
import '../usecases/auth_usecases.dart';
import '../usecases/user_signup_usecase.dart';
import '../repositories/auth_repository.dart';

class AuthService extends ChangeNotifier {
  final SignUpTherapistUseCase _signUpTherapistUseCase;
  final SignUpUserUseCase _signUpUserUseCase;
  final SignInUseCase _signInUseCase;
  final SignOutUseCase _signOutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final AuthRepository _repository;

  AuthService({
    required SignUpTherapistUseCase signUpTherapistUseCase,
    required SignUpUserUseCase signUpUserUseCase,
    required SignInUseCase signInUseCase,
    required SignOutUseCase signOutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required AuthRepository repository,
  }) : _signUpTherapistUseCase = signUpTherapistUseCase,
       _signUpUserUseCase = signUpUserUseCase,
       _signInUseCase = signInUseCase,
       _signOutUseCase = signOutUseCase,
       _getCurrentUserUseCase = getCurrentUserUseCase,
       _repository = repository {
    _init();
  }

  AuthState _state = AuthState.initial();
  AuthState get state => _state;

  StreamSubscription<User?>? _authSubscription;
  bool _isAuthActionInProgress = false;
  bool _isDisposed = false;

  AppUser? get currentUser => _state.user;

  bool get isAuthenticated => _state.status == AuthStatus.authenticated;
  bool get isLoading => _state.isLoading;
  String? get error => _state.error;
  bool get isGoogleSignInAvailable => _repository.isGoogleSignInAvailable;

  void _init() {
    _authSubscription = _repository.authStateChanges.listen((user) {
      if (kDebugMode) {
        debugPrint(
          'Auth state changed: ${user == null ? 'signed_out' : 'signed_in'}',
        );
      }
      if (_isAuthActionInProgress) {
        return;
      }

      unawaited(_syncCurrentSession(hasFirebaseUser: user != null));
    });
  }

  Future<RegistrationSuccess?> signUpTherapist({
    required String email,
    required String password,
    required String name,
    required String professionalTitle,
    required String licenseNumber,
    required String licenseIssuingAuthority,
    required String licenseRegion,
    required DateTime licenseExpiresAt,
    required String credentialEvidenceSummary,
  }) async {
    return _runRegistrationAction(
      () => _signUpTherapistUseCase.call(
        email: email,
        password: password,
        name: name,
        professionalTitle: professionalTitle,
        licenseNumber: licenseNumber,
        licenseIssuingAuthority: licenseIssuingAuthority,
        licenseRegion: licenseRegion,
        licenseExpiresAt: licenseExpiresAt,
        credentialEvidenceSummary: credentialEvidenceSummary,
      ),
      email: email,
      successMessage:
          'Therapist account created. Complete your profile after signing in while our team reviews your credentials.',
      role: UserRole.therapist,
      nameHint: name,
    );
  }

  Future<RegistrationSuccess?> signUpUser({
    required String email,
    required String password,
    required String name,
  }) async {
    return _runRegistrationAction(
      () =>
          _signUpUserUseCase.call(email: email, password: password, name: name),
      email: email,
      successMessage:
          'Account created. Please sign in with the email and password you just used.',
      role: UserRole.user,
      nameHint: name,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _runAuthAction(
      () => _signInUseCase.call(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    try {
      if (kDebugMode) {
        debugPrint('Sign-out requested');
      }
      _isAuthActionInProgress = true;
      _setState(AuthState.loading());
      await _signOutUseCase.call();
      _setState(AuthState.unauthenticated());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Sign-out failed with ${e.runtimeType}');
      }
      _setState(AuthState.unauthenticated(e.toString()));
    } finally {
      _isAuthActionInProgress = false;
    }
  }

  Future<void> signInWithGoogle() async {
    await _runAuthAction(_repository.signInWithGoogle);
  }

  void clearError() {
    if (_state.error != null) {
      _setState(_state.copyWith(error: null));
    }
  }

  Future<void> _runAuthAction(
    Future<void> Function() action, {
    UserRole? roleHint,
    String? nameHint,
  }) async {
    try {
      _isAuthActionInProgress = true;
      _setState(AuthState.loading());
      await action();
      await _syncCurrentSession(
        hasFirebaseUser: true,
        roleHint: roleHint,
        nameHint: nameHint,
      );
    } on AuthCancelledFailure {
      _setState(AuthState.unauthenticated());
    } on AuthFailure catch (e) {
      _setState(AuthState.unauthenticated(e.message));
    } catch (e) {
      _setState(AuthState.unauthenticated(e.toString()));
    } finally {
      _isAuthActionInProgress = false;
    }
  }

  Future<RegistrationSuccess?> _runRegistrationAction(
    Future<void> Function() action, {
    required String email,
    required String successMessage,
    required UserRole role,
    String? nameHint,
  }) async {
    try {
      _isAuthActionInProgress = true;
      _setState(AuthState.loading());
      await action();

      // Sign-up with Firebase also signs the user in. We repair the profile if
      // needed, then sign back out so registration returns to the login flow.
      await _repository.ensureCurrentUserProfile(
        roleHint: role,
        nameHint: nameHint,
      );
      await _signOutUseCase.call();

      _setState(AuthState.unauthenticated());
      return RegistrationSuccess(email: email, message: successMessage);
    } on AuthFailure catch (e) {
      _setState(AuthState.unauthenticated(e.message));
      return null;
    } catch (e) {
      _setState(AuthState.unauthenticated(e.toString()));
      return null;
    } finally {
      _isAuthActionInProgress = false;
    }
  }

  Future<void> _syncCurrentSession({
    required bool hasFirebaseUser,
    UserRole? roleHint,
    String? nameHint,
  }) async {
    if (!hasFirebaseUser) {
      _setState(AuthState.unauthenticated());
      return;
    }

    try {
      final existingUser = await _getCurrentUserUseCase.call();
      final appUser =
          existingUser ??
          await _repository.ensureCurrentUserProfile(
            roleHint: roleHint,
            nameHint: nameHint,
          );

      _setState(AuthState.authenticated(appUser));
    } on AuthFailure catch (e) {
      _setState(AuthState.unauthenticated(e.message));
    } catch (e) {
      _setState(AuthState.unauthenticated(e.toString()));
    }
  }

  void _setState(AuthState newState) {
    if (_isDisposed || _state == newState) {
      return;
    }

    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
