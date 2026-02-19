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
  })  : _signUpTherapistUseCase = signUpTherapistUseCase,
        _signUpUserUseCase = signUpUserUseCase,
        _signInUseCase = signInUseCase,
        _signOutUseCase = signOutUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        _repository = repository {
    _init();
  }

  AuthState _state = AuthState.initial();
  AuthState get state => _state;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  bool get isAuthenticated => _state.status == AuthStatus.authenticated;
  bool get isLoading => _state.isLoading;
  String? get error => _state.error;

  void _init() {
    _repository.authStateChanges.listen((user) async {
      if (user != null) {
        try {
          _currentUser = await _getCurrentUserUseCase.call();
          _setState(AuthState.authenticated(user.uid));
        } catch (e) {
          _setState(AuthState.unauthenticated(e.toString()));
        }
      } else {
        _currentUser = null;
        _setState(AuthState.unauthenticated());
      }
    });
  }

  Future<void> signUpTherapist({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _setState(AuthState.loading());
      await _signUpTherapistUseCase.call(
        email: email,
        password: password,
        name: name,
      );
      // State will be updated by auth state listener
    } on AuthFailure catch (e) {
      _setState(AuthState.unauthenticated(e.message));
    } catch (e) {
      _setState(AuthState.unauthenticated(e.toString()));
    }
  }

  Future<void> signUpUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _setState(AuthState.loading());
      await _signUpUserUseCase.call(
        email: email,
        password: password,
        name: name,
      );
      // State will be updated by auth state listener
    } on AuthFailure catch (e) {
      _setState(AuthState.unauthenticated(e.message));
    } catch (e) {
      _setState(AuthState.unauthenticated(e.toString()));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _setState(AuthState.loading());
      await _signInUseCase.call(
        email: email,
        password: password,
      );
      // State will be updated by auth state listener
    } on AuthFailure catch (e) {
      _setState(AuthState.unauthenticated(e.message));
    } catch (e) {
      _setState(AuthState.unauthenticated(e.toString()));
    }
  }

  Future<void> signOut() async {
    try {
      _setState(AuthState.loading());
      await _signOutUseCase.call();
      // State will be updated by auth state listener
    } catch (e) {
      _setState(AuthState.unauthenticated(e.toString()));
    }
  }

  void clearError() {
    if (_state.error != null) {
      _setState(_state.copyWith(error: null));
    }
  }

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }
}
