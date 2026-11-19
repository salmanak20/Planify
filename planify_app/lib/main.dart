import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/theme/app_theme.dart';
import 'package:planify_app/core/router/app_router.dart';
import 'package:planify_app/core/services/firebase_service.dart';
import 'package:planify_app/core/services/notifications_service.dart';
import 'package:planify_app/core/utils/app_snackbar.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/providers/auth_provider.dart';
import 'package:planify_app/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cache = LocalCacheService();
  try {
    await cache.migrateLegacyAccountCaches();
  } catch (error) {
    debugPrint('Private cache migration error: $error');
  }
  try {
    await FirebaseService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  // Do not await notification initialization to prevent blocking the UI
  // and causing a black screen on Android 13+ when the permission dialog is requested.
  NotificationsService.instance.initialize().catchError(
        (error) => debugPrint('Notification initialization error: $error'),
      );
  runApp(ProviderScope(
    overrides: [localCacheServiceProvider.overrideWithValue(cache)],
    child: const PlanifyApp(),
  ));
}

class PlanifyApp extends ConsumerWidget {
  const PlanifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authProvider, (previous, auth) {
      if (!auth.isInitialized) return;
      final uid = auth.isAuthenticated ? auth.firebaseUid : null;
      final previousUid =
          previous?.isAuthenticated == true ? previous?.firebaseUid : null;
      if (previous?.isInitialized == true && uid == previousUid) return;
      final notifications = NotificationsService.instance;
      notifications.activateAccount(uid).then((_) {
        if (uid != null) {
          return notifications.restoreCachedReminders(
            uid: uid,
            cache: ref.read(localCacheServiceProvider),
          );
        }
      }).catchError((error) {
        debugPrint('Notification restoration error: $error');
      });
    });
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'Planify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
