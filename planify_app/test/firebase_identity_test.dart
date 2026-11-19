import 'package:flutter_test/flutter_test.dart';
import 'package:planify_app/core/utils/firebase_identity.dart';

void main() {
  group('Firebase operation ownership', () {
    test('accepts an operation only for its active Firebase UID', () {
      expect(
        requireExpectedFirebaseUid('uid-a', 'uid-a'),
        'uid-a',
      );
    });

    test('rejects an operation after the active account changes', () {
      expect(
        () => requireExpectedFirebaseUid('uid-a', 'uid-b'),
        throwsA(isA<FirebaseSessionChangedException>()),
      );
    });

    test('rejects private operations without an authenticated UID', () {
      expect(
        () => requireExpectedFirebaseUid('uid-a', null),
        throwsA(isA<FirebaseSessionChangedException>()),
      );
      expect(
        () => requireExpectedFirebaseUid(null, null),
        throwsA(isA<FirebaseSessionChangedException>()),
      );
    });
  });
}
