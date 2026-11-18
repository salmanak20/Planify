import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/providers/auth_provider.dart';

/// UID for account-owned providers. It is null during auth restoration,
/// signed-out states, and profile errors so old data is disposed immediately.
final activeAccountUidProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return null;
  return auth.firebaseUid;
});
