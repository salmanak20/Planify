import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planify_app/data/repositories/insights_repository.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/data/repositories/auth_repository.dart';
import 'package:planify_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    SharedPreferences.setMockInitialValues({
      'has_completed_onboarding': true,
    });
    await Firebase.initializeApp();
  });

  testWidgets('PlanifyApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PlanifyApp()));
    // Auth check happens async; just ensure app renders without crashing.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byType(ProviderScope), findsOneWidget);
  });

  test('Smart Insight returns a safe fallback on API failure', () async {
    final repository = InsightsRepository(
      apiBaseUrl: 'https://api.example.test',
      idTokenProvider: () async => 'test-token',
      httpClientFactory: () => MockClient(
        (_) async => http.Response('provider details', 502),
      ),
    );

    final insight = await repository.generateSmartInsight([], []);

    expect(
      insight,
      'Smart insights are unavailable right now. Try again later.',
    );
  });

  test('cached profile is rejected when its Firebase UID does not match',
      () async {
    final cache = LocalCacheService();
    await cache.saveJsonMap('auth_user', {
      'id': 1,
      'email': 'a@example.test',
      'full_name': 'Account A',
      'avatar_color': '#435f92',
      'firebase_uid': 'uid-a',
    });
    final repository = AuthRepository(cache);

    expect(await repository.getCachedUser('uid-b'), isNull);
    expect((await repository.getCachedUser('uid-a'))?.fullName, 'Account A');
  });

  test('Smart Insight sends the provided current Firebase ID token', () async {
    http.Request? capturedRequest;
    final repository = InsightsRepository(
      apiBaseUrl: 'https://api.example.test',
      idTokenProvider: () async => 'current-firebase-id-token',
      httpClientFactory: () => MockClient((request) async {
        capturedRequest = request;
        return http.Response('{"insight":"Try one focused task."}', 200);
      }),
    );

    expect(
        await repository.generateSmartInsight([], []), 'Try one focused task.');
    expect(capturedRequest?.headers['Authorization'],
        'Bearer current-firebase-id-token');
  });

  test('Smart Insight after logout does not send a request without a token',
      () async {
    var requestSent = false;
    final repository = InsightsRepository(
      apiBaseUrl: 'https://api.example.test',
      idTokenProvider: () async => null,
      httpClientFactory: () => MockClient((_) async {
        requestSent = true;
        return http.Response('{}', 200);
      }),
    );

    await repository.generateSmartInsight([], []);

    expect(requestSent, isFalse);
  });
}
