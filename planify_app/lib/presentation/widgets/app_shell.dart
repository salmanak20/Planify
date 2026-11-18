import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planify_app/core/theme/app_theme.dart';

/// Glassmorphic bottom navigation shell wrapping the 5 main tabs.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _tabs = [
    (
      path: '/dashboard',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    (
      path: '/tasks',
      icon: Icons.check_circle_outline,
      activeIcon: Icons.check_circle_rounded,
      label: 'Tasks',
    ),
    (
      path: '/calendar',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Calendar',
    ),
    (
      path: '/reminders',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications_rounded,
      label: 'Reminders',
    ),
    (
      path: '/notes',
      icon: Icons.description_outlined,
      activeIcon: Icons.description_rounded,
      label: 'Notes',
    ),
  ];

  String _currentLocation(BuildContext context) {
    return GoRouterState.of(context).matchedLocation;
  }

  int _currentIndex(BuildContext context) {
    final location = _currentLocation(context);
    final idx = _tabs.indexWhere((t) => location.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    final isHome = _currentLocation(context) == '/dashboard';
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: isHome,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || isHome) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: cs.surface.withAlpha(230),
            boxShadow: [
              BoxShadow(
                color: cs.onSurface.withAlpha(15),
                blurRadius: 24,
                offset: const Offset(0, -4),
                spreadRadius: -4,
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final isSelected = i == currentIndex;
                  return GestureDetector(
                    onTap: () => context.go(tab.path),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 16 : 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.secondaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? tab.activeIcon : tab.icon,
                            color: isSelected
                                ? AppTheme.onSecondaryContainer
                                : cs.onSurfaceVariant,
                            size: 22,
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Text(
                              tab.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppTheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
