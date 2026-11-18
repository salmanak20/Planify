import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planify_app/providers/auth_provider.dart';
import 'package:planify_app/presentation/screens/auth/login_screen.dart';
import 'package:planify_app/presentation/screens/auth/register_screen.dart';
import 'package:planify_app/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:planify_app/presentation/screens/tasks/tasks_screen.dart';
import 'package:planify_app/presentation/screens/notes/notes_screen.dart';
import 'package:planify_app/presentation/screens/calendar/calendar_screen.dart';
import 'package:planify_app/presentation/screens/workspace/workspace_screen.dart';
import 'package:planify_app/presentation/screens/focus/focus_screen.dart';
import 'package:planify_app/presentation/screens/reminders/reminders_screen.dart';
import 'package:planify_app/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:planify_app/presentation/widgets/app_shell.dart';
import 'package:planify_app/providers/onboarding_provider.dart';
import 'package:planify_app/presentation/screens/splash/splash_screen.dart';

/// Drives [GoRouter.refreshListenable] so redirects re-run when auth or
/// onboarding change, without disposing and recreating [GoRouter] (which can
/// leave a blank screen) and without stale values captured in the redirect
/// closure from an old router build.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    _ref.listen<bool>(onboardingProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final hasOnboarded = ref.read(onboardingProvider);

      if (state.matchedLocation == '/splash') {
        return null;
      }

      if (authState.status == AuthStatus.loading || !authState.isInitialized) {
        return '/splash';
      }

      if (!hasOnboarded && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }

      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn &&
          !isAuthRoute &&
          state.matchedLocation != '/onboarding') {
        return '/login';
      }
      if (hasOnboarded && state.matchedLocation == '/onboarding') {
        return isLoggedIn ? '/dashboard' : '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),

      // ── Main Shell (Bottom Nav) ────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (_, __) => const TasksScreen(),
          ),
          GoRoute(
            path: '/calendar',
            builder: (_, __) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/notes',
            builder: (_, __) => const NotesScreen(),
          ),
          GoRoute(
            path: '/workspace',
            builder: (_, __) => const WorkspaceScreen(),
          ),
          GoRoute(
            path: '/reminders',
            builder: (_, __) => const RemindersScreen(),
          ),
        ],
      ),

      // ── Focus Mode (Full screen, no bottom nav) ────────────────────────────
      GoRoute(
        path: '/focus',
        builder: (_, __) => const FocusScreen(),
      ),
    ],
  );
});
