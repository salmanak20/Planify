import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planify_app/data/models/user_model.dart';
import 'package:planify_app/data/repositories/auth_repository.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Firebase auth lifecycle', () {
    late FakeAuthRepository repository;
    late AuthNotifier notifier;

    setUp(() {
      repository = FakeAuthRepository();
      notifier = AuthNotifier(repository);
    });

    tearDown(() async {
      notifier.dispose();
      await repository.close();
    });

    test('A: no Firebase user and no cached profile is unauthenticated',
        () async {
      expect(notifier.state.status, AuthStatus.loading);
      repository.emit(null);
      await notifier.waitUntilInitialized();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.isAuthenticated, isFalse);
    });

    test('B and H: cached profile without Firebase session is ignored',
        () async {
      repository.hasCachedProfile = true;
      repository.emit(null);
      await notifier.waitUntilInitialized();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.user, isNull);
    });

    test('C and G: restored Firebase session loads matching profile', () async {
      final user = TestFirebaseUser('uid-a');
      repository.emit(user);
      await notifier.waitUntilInitialized();

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.firebaseUid, 'uid-a');
      expect(notifier.state.user?.fullName, 'User uid-a');
    });

    test('D: missing profile is created only for the current Firebase UID',
        () async {
      repository.missingProfiles.add('uid-a');
      repository.emit(TestFirebaseUser('uid-a'));
      await notifier.waitUntilInitialized();

      expect(notifier.state.isAuthenticated, isTrue);
      expect(repository.createdProfileUids, contains('uid-a'));
    });

    test('E: profile UID mismatch is rejected', () async {
      repository.mismatchedProfiles.add('uid-a');
      repository.emit(TestFirebaseUser('uid-a'));
      await notifier.waitUntilInitialized();

      expect(notifier.state.status, AuthStatus.error);
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.user, isNull);
    });

    test('F: account switching never exposes the previous profile', () async {
      repository.emit(TestFirebaseUser('uid-a'));
      await notifier.waitUntilInitialized();
      expect(notifier.state.user?.fullName, 'User uid-a');

      repository.emit(null);
      await _until(() => notifier.state.status == AuthStatus.unauthenticated);
      repository.emit(TestFirebaseUser('uid-b'));
      await _until(() => notifier.state.status == AuthStatus.authenticated);

      expect(notifier.state.firebaseUid, 'uid-b');
      expect(notifier.state.user?.fullName, 'User uid-b');
    });

    test('stale Account A profile result cannot replace Account B', () async {
      final delayed = Completer<UserModel>();
      repository.delayedProfiles['uid-a'] = delayed;
      repository.emit(TestFirebaseUser('uid-a'));
      await Future<void>.delayed(Duration.zero);
      repository.emit(TestFirebaseUser('uid-b'));
      await _until(() =>
          notifier.state.firebaseUid == 'uid-b' &&
          notifier.state.status == AuthStatus.authenticated);
      delayed.complete(FakeAuthRepository.profile('uid-a'));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.firebaseUid, 'uid-b');
      expect(notifier.state.user?.fullName, 'User uid-b');
    });
  });
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue);
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(LocalCacheService());

  final StreamController<User?> _users =
      StreamController<User?>.broadcast(sync: true);
  final Set<String> missingProfiles = {};
  final Set<String> mismatchedProfiles = {};
  final Set<String> createdProfileUids = {};
  final Map<String, Completer<UserModel>> delayedProfiles = {};
  String? _uid;
  bool hasCachedProfile = false;

  @override
  bool get requiresFirebaseInitialization => false;

  @override
  String? get currentUserUid => _uid;

  @override
  Stream<User?> get idTokenChanges => _users.stream;

  void emit(User? user) {
    _uid = user?.uid;
    _users.add(user);
  }

  @override
  Future<void> clearCachedUser({String? expectedUid}) async {
    hasCachedProfile = false;
  }

  @override
  Future<UserModel> loadProfile(User user,
      {String? fallbackEmail, String? fullName, String? occupation}) async {
    if (currentUserUid != user.uid || mismatchedProfiles.contains(user.uid)) {
      throw const ProfileOwnershipException();
    }
    final pending = delayedProfiles[user.uid];
    if (pending != null) return pending.future;
    if (missingProfiles.contains(user.uid)) createdProfileUids.add(user.uid);
    return profile(user.uid);
  }

  @override
  Future<UserModel> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<UserModel> register({
    required String email,
    required String fullName,
    required String password,
    String? occupation,
  }) =>
      throw UnimplementedError();

  @override
  Future<UserModel> syncFirebaseUser({String? fullName, String? occupation}) =>
      throw UnimplementedError();

  static UserModel profile(String uid) => UserModel(
        id: uid.hashCode,
        email: '$uid@example.test',
        fullName: 'User $uid',
        avatarColor: '#435f92',
      );

  Future<void> close() => _users.close();
}

class TestFirebaseUser implements User {
  TestFirebaseUser(this.uid);

  @override
  final String uid;

  @override
  String? get email => '$uid@example.test';

  @override
  String? get displayName => 'User $uid';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
