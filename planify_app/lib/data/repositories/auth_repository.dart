import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/utils/firebase_identity.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/data/models/user_model.dart';

const _authUserCacheKey = 'auth_user';

class ProfileOwnershipException implements Exception {
  const ProfileOwnershipException();

  @override
  String toString() => 'Profile does not belong to the signed-in account.';
}

class AuthRepository {
  final LocalCacheService _cache;
  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  AuthRepository(
    this._cache, {
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _authOverride = auth,
        _firestoreOverride = firestore;

  FirebaseAuth get _firebaseAuth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  bool get requiresFirebaseInitialization => _authOverride == null;
  String? get currentUserUid => _firebaseAuth.currentUser?.uid;
  Stream<User?> get idTokenChanges => _firebaseAuth.idTokenChanges();

  Future<UserModel> register({
    required String email,
    required String fullName,
    required String password,
    String? occupation,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Firebase did not return a user.');
    await user.updateDisplayName(fullName);
    final profile = UserModel(
      id: stableUserIdFromUid(user.uid),
      email: email,
      fullName: fullName,
      avatarColor: '#435f92',
    );
    await _firestore.collection('users').doc(user.uid).set(
          _userDocument(profile, user.uid, occupation: occupation),
        );
    await _saveCacheForCurrentUser(profile, user.uid);
    return profile;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Firebase did not return a user.');
    return loadProfile(user, fallbackEmail: email);
  }

  Future<UserModel> syncFirebaseUser({
    String? fullName,
    String? occupation,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No Firebase user is signed in.');
    return loadProfile(user, fullName: fullName, occupation: occupation);
  }

  /// Loads or creates the profile only for the supplied authenticated identity.
  Future<UserModel> loadProfile(
    User user, {
    String? fallbackEmail,
    String? fullName,
    String? occupation,
  }) async {
    if (_firebaseAuth.currentUser?.uid != user.uid) {
      throw const ProfileOwnershipException();
    }
    final profile = await _loadOrCreateUserProfile(
      user: user,
      fallbackEmail: fallbackEmail ?? user.email ?? '',
      fallbackName: fullName ?? user.displayName ?? 'Unknown',
      occupation: occupation,
    );
    await _saveCacheForCurrentUser(profile, user.uid);
    if (_firebaseAuth.currentUser?.uid != user.uid) {
      throw const ProfileOwnershipException();
    }
    return profile;
  }

  Future<UserModel?> getCachedUser(String expectedUid) async {
    final cached = await _cache.readJsonMap(_authUserCacheKey);
    if (cached == null || cached['firebase_uid'] != expectedUid) return null;
    return UserModel.fromJson(cached);
  }

  Future<void> clearCachedUser({String? expectedUid}) async {
    if (expectedUid == null) return;
    final cached = await _cache.readJsonMap(_authUserCacheKey);
    if (cached?['firebase_uid'] == expectedUid) {
      await _cache.remove(_authUserCacheKey);
    }
  }

  Future<void> logout() async {
    final uid = currentUserUid;
    await _firebaseAuth.signOut();
    await clearCachedUser(expectedUid: uid);
  }

  Future<bool> isLoggedIn() async => currentUserUid != null;

  Future<void> _saveCacheForCurrentUser(UserModel profile, String uid) async {
    if (_firebaseAuth.currentUser?.uid != uid) {
      throw const ProfileOwnershipException();
    }
    await _cache.saveJsonMap(_authUserCacheKey, {
      ...profile.toJson(),
      'firebase_uid': uid,
    });
    if (_firebaseAuth.currentUser?.uid != uid) {
      await clearCachedUser(expectedUid: uid);
      throw const ProfileOwnershipException();
    }
  }

  Future<UserModel> _loadOrCreateUserProfile({
    required User user,
    required String fallbackEmail,
    required String fallbackName,
    String? occupation,
  }) async {
    final userId = stableUserIdFromUid(user.uid);
    final userDoc = _firestore.collection('users').doc(user.uid);
    final doc = await userDoc.get();

    if (doc.exists) {
      final data = doc.data()!;
      _validateOwner(data, user.uid);
      final profile = UserModel.fromJson({...data, 'id': data['id'] ?? userId});
      await userDoc.set(
        _userDocument(
          profile,
          user.uid,
          occupation: data['occupation'] as String? ?? occupation,
        ),
        SetOptions(merge: true),
      );
      return profile;
    }

    final legacyData = await _tryLoadLegacyUserData(user.uid);
    if (legacyData != null) {
      _validateOwner(legacyData, user.uid);
      final migrated = UserModel.fromJson({...legacyData, 'id': userId});
      await userDoc.set(
        _userDocument(
          migrated,
          user.uid,
          occupation: legacyData['occupation'] as String? ?? occupation,
        ),
        SetOptions(merge: true),
      );
      return migrated;
    }

    final profile = UserModel(
      id: userId,
      email: user.email ?? fallbackEmail,
      fullName: fallbackName,
      avatarColor: '#435f92',
    );
    await userDoc.set(_userDocument(profile, user.uid, occupation: occupation));
    return profile;
  }

  void _validateOwner(Map<String, dynamic> data, String expectedUid) {
    final owner = data['firebase_uid'];
    if (owner != null && owner != expectedUid) {
      throw const ProfileOwnershipException();
    }
  }

  Map<String, dynamic> _userDocument(
    UserModel user,
    String firebaseUid, {
    String? occupation,
  }) {
    final data = withFirebaseOwner(user.toJson(), firebaseUid);
    if (occupation != null && occupation.isNotEmpty) {
      data['occupation'] = occupation;
    }
    return data;
  }

  Future<Map<String, dynamic>?> _tryLoadLegacyUserData(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid.hashCode.toString())
          .get();
      return doc.data();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return null;
      rethrow;
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(localCacheServiceProvider)),
);
