import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planify_app/data/datasources/cache_keys.dart';

class CacheSession {
  const CacheSession._(this.uid, this.generation);

  final String uid;
  final int generation;
}

class CacheSessionInvalidatedException implements Exception {
  const CacheSessionInvalidatedException();

  @override
  String toString() => 'The signed-in account changed during this operation.';
}

class LocalCacheService {
  LocalCacheService({Future<SharedPreferences> Function()? preferencesLoader})
      : _prefs = (preferencesLoader ?? SharedPreferences.getInstance)();

  final Future<SharedPreferences> _prefs;
  Future<void> _queue = Future<void>.value();
  String? _activeUid;
  int _generation = 0;

  String? get activeUid => _activeUid;

  /// Changes the account permitted to read or write private cache entries.
  /// Repeated auth token events for the same UID keep the current generation.
  void activateUser(String? uid) {
    if (uid != null) {
      // Reuse centralized UID validation before making it active.
      CacheKeys.profile(uid);
    }
    if (uid == _activeUid) return;
    _generation++;
    _activeUid = uid;
  }

  void invalidateUser(String? expectedUid) {
    if (expectedUid == null || _activeUid == expectedUid) {
      activateUser(null);
    }
  }

  CacheSession captureSession(String uid) {
    CacheKeys.profile(uid);
    if (_activeUid != uid) throw const CacheSessionInvalidatedException();
    return CacheSession._(uid, _generation);
  }

  bool isSessionCurrent(CacheSession session) =>
      _activeUid == session.uid && _generation == session.generation;

  void ensureSessionCurrent(CacheSession session) {
    if (!isSessionCurrent(session)) {
      throw const CacheSessionInvalidatedException();
    }
  }

  Future<Map<String, dynamic>?> readJsonMapForUser(
    CacheSession session,
    UserCacheKey key,
  ) {
    _checkKeySession(session, key);
    return _serialized(() async {
      ensureSessionCurrent(session);
      final prefs = await _prefs;
      ensureSessionCurrent(session);
      final raw = prefs.getString(key.value);
      if (raw == null || raw.isEmpty) return null;
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      ensureSessionCurrent(session);
      return decoded;
    });
  }

  Future<List<Map<String, dynamic>>> readJsonListForUser(
    CacheSession session,
    UserCacheKey key,
  ) {
    _checkKeySession(session, key);
    return _serialized(() async {
      ensureSessionCurrent(session);
      final prefs = await _prefs;
      ensureSessionCurrent(session);
      final raw = prefs.getString(key.value);
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw) as List<dynamic>;
      final values = decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      ensureSessionCurrent(session);
      return values;
    });
  }

  Future<List<String>> readStringListForUser(
    CacheSession session,
    UserCacheKey key,
  ) {
    _checkKeySession(session, key);
    return _serialized(() async {
      ensureSessionCurrent(session);
      final prefs = await _prefs;
      ensureSessionCurrent(session);
      final values = prefs.getStringList(key.value) ?? <String>[];
      ensureSessionCurrent(session);
      return values;
    });
  }

  Future<void> saveJsonMapForUser(
    CacheSession session,
    UserCacheKey key,
    Map<String, dynamic> value,
  ) =>
      _saveForUser(session, key, jsonEncode(value));

  Future<void> saveJsonListForUser(
    CacheSession session,
    UserCacheKey key,
    List<Map<String, dynamic>> values,
  ) =>
      _saveForUser(session, key, jsonEncode(values));

  Future<void> saveStringListForUser(
    CacheSession session,
    UserCacheKey key,
    List<String> values,
  ) {
    _checkKeySession(session, key);
    return _serialized(() async {
      ensureSessionCurrent(session);
      final prefs = await _prefs;
      ensureSessionCurrent(session);
      await prefs.setStringList(key.value, values);
      if (!isSessionCurrent(session)) {
        if (jsonEncode(prefs.getStringList(key.value)) == jsonEncode(values)) {
          await prefs.remove(key.value);
        }
        throw const CacheSessionInvalidatedException();
      }
    });
  }

  Future<void> removeForUser(CacheSession session, UserCacheKey key) {
    _checkKeySession(session, key);
    return _serialized(() async {
      ensureSessionCurrent(session);
      final prefs = await _prefs;
      ensureSessionCurrent(session);
      await prefs.remove(key.value);
      ensureSessionCurrent(session);
    });
  }

  /// Clears only the supplied user's private keys; global preferences survive.
  Future<void> clearUserCache(String uid) {
    final keys = CacheKeys.forUser(uid);
    return _serialized(() async {
      final prefs = await _prefs;
      for (final key in keys) {
        await prefs.remove(key.value);
      }
    });
  }

  /// Removes known unscoped private caches. Safe to call on every startup.
  Future<void> migrateLegacyAccountCaches() => _serialized(() async {
        final prefs = await _prefs;
        for (final key in CacheKeys.legacyAccountSpecificKeys) {
          await prefs.remove(key);
        }
      });

  /// Demo fixtures remain in their own non-private namespace.
  Future<List<Map<String, dynamic>>> readDemoJsonList(DemoCacheKey key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key.value);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> saveDemoJsonList(
    DemoCacheKey key,
    List<Map<String, dynamic>> values,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(key.value, jsonEncode(values));
  }

  Future<void> _saveForUser(
    CacheSession session,
    UserCacheKey key,
    String raw,
  ) {
    _checkKeySession(session, key);
    return _serialized(() async {
      ensureSessionCurrent(session);
      final prefs = await _prefs;
      ensureSessionCurrent(session);
      await prefs.setString(key.value, raw);
      if (!isSessionCurrent(session)) {
        // If logout races a platform write, remove only the value this
        // operation wrote. The serialized queue then runs logout cleanup.
        if (prefs.getString(key.value) == raw) {
          await prefs.remove(key.value);
        }
        throw const CacheSessionInvalidatedException();
      }
    });
  }

  void _checkKeySession(CacheSession session, UserCacheKey key) {
    if (session.uid != key.uid) {
      throw ArgumentError('Cache key UID does not match the active session.');
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

final localCacheServiceProvider = Provider<LocalCacheService>(
  (ref) => LocalCacheService(),
);
