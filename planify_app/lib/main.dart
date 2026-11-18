import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/theme/app_theme.dart';
import 'package:planify_app/core/router/app_router.dart';
import 'package:planify_app/core/services/firebase_service.dart';
import 'package:planify_app/core/services/notifications_service.dart';
import 'package:planify_app/core/utils/app_snackbar.dart';
import 'package:planify_app/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FirebaseService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  // Do not await notification initialization to prevent blocking the UI
  // and causing a black screen on Android 13+ when the permission dialog is requested.
  NotificationsService.instance
      .initialize()
      .then((_) => NotificationsService.instance.restoreCachedReminders())
      .catchError(
        (error) => debugPrint('Notification initialization error: $error'),
      );
  runApp(const ProviderScope(child: PlanifyApp()));
}

class PlanifyApp extends ConsumerWidget {
  const PlanifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
