import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

const _networkErrorMessage = 'Network Error. Check you internet connection';

class FirebaseService {
  FirebaseService._();

  static Object? _initializationError;

  static bool get isInitialized => Firebase.apps.isNotEmpty;

  static Object? get initializationError => _initializationError;

  static String get unavailableReason {
    if (_initializationError != null) {
      final message = _initializationError.toString().toLowerCase();
      if (message.contains('network') ||
          message.contains('socket') ||
          message.contains('connection') ||
          message.contains('timed out') ||
          message.contains('unavailable')) {
        return _networkErrorMessage;
      }

      return 'Firebase is not configured correctly. Refresh the Firebase app config and try again.';
    }

    return 'Firebase is not available on this platform.';
  }

  static Future<void> initialize() async {
    if (isInitialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initializationError = null;
    } catch (error) {
      _initializationError = error;
      rethrow;
    }
  }
}
