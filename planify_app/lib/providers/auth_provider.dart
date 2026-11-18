import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:planify_app/core/services/firebase_service.dart';
import 'package:planify_app/data/models/user_model.dart';
import 'package:planify_app/data/repositories/auth_repository.dart';

const _networkErrorMessage = 'Network Error. Check you internet connection';

enum AuthStatus { loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? firebaseUid;
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  const AuthState({
    this.status = AuthStatus.loading,
    this.user,
    this.firebaseUid,
    this.isLoading = true,
    this.isInitialized = false,
    this.error,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && firebaseUid != null && user != null;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool clearUser = false,
    String? firebaseUid,
    bool clearFirebaseUid = false,
    bool? isLoading,
    bool? isInitialized,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : user ?? this.user,
        firebaseUid: clearFirebaseUid ? null : firebaseUid ?? this.firebaseUid,
        isLoading: isLoading ?? this.isLoading,
        isInitialized: isInitialized ?? this.isInitialized,
        error: clearError ? null : error ?? this.error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final Completer<void> _initCompleter = Completer<void>();
  final Map<String, Completer<void>> _uidSettlements = {};
  StreamSubscription<User?>? _authSubscription;
  int _generation = 0;
  String? _activeFirebaseUid;

  AuthNotifier(this._repo) : super(const AuthState()) {
    _listenToFirebaseAuth();
  }

  Future<void> waitUntilInitialized() => _initCompleter.future;

  void _listenToFirebaseAuth() {
    try {
      if (!FirebaseService.isInitialized &&
          _repo.requiresFirebaseInitialization) {
        throw StateError(FirebaseService.unavailableReason);
      }
      _authSubscription = _repo.idTokenChanges.listen(
        _handleAuthUser,
        onError: _handleAuthStreamError,
      );
    } catch (error) {
      _handleAuthStreamError(error);
    }
  }

  void _handleAuthStreamError(Object error, [StackTrace? stackTrace]) {
    _generation++;
    state = AuthState(
      status: AuthStatus.error,
      isLoading: false,
      isInitialized: true,
      error: _parseError(error),
    );
    _completeInitialization();
  }

  Future<void> _handleAuthUser(User? firebaseUser) async {
    final generation = ++_generation;
    final previousUid = _activeFirebaseUid;
    final uid = firebaseUser?.uid;
    _activeFirebaseUid = uid;
    state = AuthState(
      status: firebaseUser == null
          ? AuthStatus.unauthenticated
          : AuthStatus.loading,
      firebaseUid: uid,
      isLoading: firebaseUser != null,
      isInitialized: false,
    );

    if (firebaseUser == null) {
      try {
        await _repo.clearCachedUser(expectedUid: previousUid);
      } catch (_) {
        // Sign-out state is authoritative even when local cache cleanup fails.
      }
      if (!mounted || generation != _generation) return;
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        isInitialized: true,
      );
      _completeInitialization();
      return;
    }

    try {
      final user = await _repo.loadProfile(firebaseUser);
      if (!mounted ||
          generation != _generation ||
          _repo.currentUserUid != uid) {
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        firebaseUid: uid,
        isLoading: false,
        isInitialized: true,
      );
    } catch (error) {
      if (!mounted ||
          generation != _generation ||
          _repo.currentUserUid != uid) {
        return;
      }
      state = AuthState(
        status: AuthStatus.error,
        firebaseUid: uid,
        isLoading: false,
        isInitialized: true,
        error: _parseError(error),
      );
    } finally {
      if (mounted && generation == _generation) {
        if (uid != null) _completeUidSettlement(uid);
        _completeInitialization();
      }
    }
  }

  Future<void> _waitForCurrentProfile() async {
    final uid = _repo.currentUserUid;
    if (uid == null) return;
    if (state.firebaseUid == uid &&
        state.isInitialized &&
        state.status != AuthStatus.loading) {
      return;
    }
    final completer = _uidSettlements.putIfAbsent(uid, Completer<void>.new);
    await completer.future.timeout(const Duration(seconds: 15));
  }

  void _completeUidSettlement(String uid) {
    final completer = _uidSettlements.remove(uid);
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _completeInitialization() {
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  Future<bool> login(String email, String password) async {
    final actionGeneration = _generation;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.login(email: email, password: password);
      await _waitForCurrentProfile();
      return state.isAuthenticated;
    } catch (error) {
      if (actionGeneration == _generation && mounted) {
        state = state.copyWith(isLoading: false, error: _parseError(error));
      }
      return false;
    }
  }

  Future<bool> register(String email, String fullName, String password,
      {String? occupation}) async {
    final actionGeneration = _generation;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.register(
        email: email,
        fullName: fullName,
        password: password,
        occupation: occupation,
      );
      await _waitForCurrentProfile();
      return state.isAuthenticated;
    } catch (error) {
      if (actionGeneration == _generation && mounted) {
        state = state.copyWith(isLoading: false, error: _parseError(error));
      }
      return false;
    }
  }

  Future<bool> googleSignIn({String? occupation}) async {
    if (!FirebaseService.isInitialized) {
      state = state.copyWith(
        isLoading: false,
        error: FirebaseService.unavailableReason,
      );
      return false;
    }
    final actionGeneration = _generation;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      final googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw StateError(
            'Google Sign-In did not return a Firebase credential.');
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (occupation != null && occupation.isNotEmpty) {
        await _repo.syncFirebaseUser(occupation: occupation);
      }
      await _waitForCurrentProfile();
      return state.isAuthenticated;
    } catch (error) {
      if (actionGeneration == _generation && mounted) {
        state = state.copyWith(isLoading: false, error: _parseError(error));
      }
      return false;
    }
  }

  Future<void> logout() async {
    final previousUid = _activeFirebaseUid;
    state = const AuthState(status: AuthStatus.loading, isLoading: true);
    try {
      await _clearGoogleSession();
      await _repo.clearCachedUser(expectedUid: previousUid);
    } catch (error) {
      state = AuthState(
        status: AuthStatus.error,
        isLoading: false,
        isInitialized: true,
        error: _parseError(error),
      );
    }
  }

  Future<void> _clearGoogleSession() async {
    if (FirebaseService.isInitialized) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    for (final completer in _uidSettlements.values) {
      if (!completer.isCompleted) completer.complete();
    }
    super.dispose();
  }

  String _parseError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'network-request-failed':
          return _networkErrorMessage;
        case 'account-exists-with-different-credential':
          return 'This email is already linked to a different sign-in method.';
        case 'invalid-credential':
        case 'invalid-verification-code':
          return 'Firebase credentials were rejected. Refresh the Firebase app config and try again.';
        case 'operation-not-allowed':
          return 'Google Sign-In is not enabled for this Firebase project.';
        case 'email-already-in-use':
          return 'Email already registered.';
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-email':
          return 'Incorrect email or password.';
      }
    }
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Firebase rejected this action. Check Firestore rules and your sign-in session.';
        case 'unavailable':
        case 'deadline-exceeded':
          return _networkErrorMessage;
      }
    }
    if (e is PlatformException) {
      final details = '${e.code} ${e.message ?? ''}'.toLowerCase();
      if (details.contains('10') || details.contains('developer_error')) {
        return 'Google Sign-In is misconfigured in Firebase. Regenerate the Android config and add SHA-1/SHA-256 fingerprints.';
      }
      if (details.contains('network') ||
          details.contains('api_exception: 7') ||
          details.contains('status: 7')) {
        return _networkErrorMessage;
      }
    }
    final msg = e.toString();
    final lowerMsg = msg.toLowerCase();
    if (msg.contains('Firebase is not configured') ||
        msg.contains('Firebase is not available')) {
      return msg;
    }
    if (lowerMsg.contains('timeoutexception') ||
        lowerMsg.contains('timed out') ||
        lowerMsg.contains('socketexception') ||
        lowerMsg.contains('connection') ||
        lowerMsg.contains('network') ||
        lowerMsg.contains('unavailable')) {
      return _networkErrorMessage;
    }
    if (msg.contains('400')) {
      return 'Email already registered.';
    }
    if (msg.contains('401')) {
      return 'Incorrect email or password.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);
