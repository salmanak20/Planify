import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planify_app/data/datasources/cache_keys.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UID scoped private caches', () {
    test('each account and private cache category has a unique key', () {
      final keysA = CacheKeys.forUser('uid-a').map((key) => key.value).toSet();
      final keysB = CacheKeys.forUser('uid-b').map((key) => key.value).toSet();

      expect(keysA, hasLength(7));
      expect(keysB, hasLength(7));
      expect(keysA.intersection(keysB), isEmpty);
      expect(CacheKeys.tasks('uid/a').value, contains('%2F'));
      expect(() => CacheKeys.tasks(''), throwsArgumentError);
      expect(() => CacheKeys.tasks(' uid-a'), throwsArgumentError);
    });

    test('account switch reads only that account cache', () async {
      final cache = LocalCacheService();
      cache.activateUser('uid-a');
      final sessionA = cache.captureSession('uid-a');
      await cache.saveJsonListForUser(sessionA, CacheKeys.tasks('uid-a'), [
        {'id': 1, 'title': 'A private task'},
      ]);

      cache.activateUser('uid-b');
      final sessionB = cache.captureSession('uid-b');
      expect(
        await cache.readJsonListForUser(sessionB, CacheKeys.tasks('uid-b')),
        isEmpty,
      );
      await cache.saveJsonListForUser(sessionB, CacheKeys.tasks('uid-b'), [
        {'id': 2, 'title': 'B private task'},
      ]);

      cache.activateUser('uid-a');
      expect(
        await cache.readJsonListForUser(
          cache.captureSession('uid-a'),
          CacheKeys.tasks('uid-a'),
        ),
        equals([
          {'id': 1, 'title': 'A private task'},
        ]),
      );
    });

    test('signed out and stale sessions cannot read or write private data',
        () async {
      final cache = LocalCacheService();
      cache.activateUser('uid-a');
      final oldSession = cache.captureSession('uid-a');
      cache.invalidateUser('uid-a');

      await expectLater(
        cache.readJsonListForUser(oldSession, CacheKeys.tasks('uid-a')),
        throwsA(isA<CacheSessionInvalidatedException>()),
      );
      await expectLater(
        cache.saveJsonListForUser(oldSession, CacheKeys.tasks('uid-a'), []),
        throwsA(isA<CacheSessionInvalidatedException>()),
      );
      expect(() => cache.captureSession('uid-a'),
          throwsA(isA<CacheSessionInvalidatedException>()));
    });

    test('logout cleanup removes only outgoing private keys', () async {
      final cache = LocalCacheService();
      cache.activateUser('uid-a');
      final session = cache.captureSession('uid-a');
      await cache.saveJsonMapForUser(session, CacheKeys.profile('uid-a'), {
        'firebase_uid': 'uid-a',
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', 'dark');
      await prefs.setBool('has_completed_onboarding', true);
      await prefs.setString(DemoCacheKey.tasks.value, 'demo-data');

      cache.invalidateUser('uid-a');
      await cache.clearUserCache('uid-a');

      expect(prefs.containsKey(CacheKeys.profile('uid-a').value), isFalse);
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getBool('has_completed_onboarding'), isTrue);
      expect(prefs.getString(DemoCacheKey.tasks.value), 'demo-data');
    });

    test('legacy migration is idempotent and preserves global settings',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tasks_cache', 'legacy-private');
      await prefs.setString('auth_user', 'legacy-profile');
      await prefs.setString('theme_mode', 'dark');
      await prefs.setBool('onboarding_complete', true);
      final cache = LocalCacheService();

      await cache.migrateLegacyAccountCaches();
      await cache.migrateLegacyAccountCaches();

      expect(prefs.containsKey('tasks_cache'), isFalse);
      expect(prefs.containsKey('auth_user'), isFalse);
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getBool('onboarding_complete'), isTrue);
    });

    test('logout racing a pending preferences load blocks stale writes',
        () async {
      final prefsReady = Completer<SharedPreferences>();
      final cache =
          LocalCacheService(preferencesLoader: () => prefsReady.future);
      cache.activateUser('uid-a');
      final session = cache.captureSession('uid-a');
      final pending = cache.saveJsonListForUser(
        session,
        CacheKeys.tasks('uid-a'),
        [
          {'id': 1},
        ],
      );
      cache.invalidateUser('uid-a');
      SharedPreferences.setMockInitialValues({});
      prefsReady.complete(await SharedPreferences.getInstance());

      await expectLater(
          pending, throwsA(isA<CacheSessionInvalidatedException>()));
      expect(
        (await SharedPreferences.getInstance())
            .containsKey(CacheKeys.tasks('uid-a').value),
        isFalse,
      );
    });
  });
}
