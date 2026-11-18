import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:planify_app/core/constants/app_flags.dart';
import 'package:planify_app/core/theme/app_theme.dart';
import 'package:planify_app/data/models/event_model.dart';
import 'package:planify_app/data/models/note_model.dart';
import 'package:planify_app/data/models/task_model.dart';
import 'package:planify_app/presentation/screens/search/search_screen.dart';
import 'package:planify_app/presentation/screens/settings/settings_screen.dart';
import 'package:planify_app/providers/auth_provider.dart';
import 'package:planify_app/providers/tasks_provider.dart';
import 'package:planify_app/providers/notes_provider.dart';
import 'package:planify_app/providers/events_provider.dart';
import 'package:planify_app/providers/insights_provider.dart';
import 'package:planify_app/providers/reminders_provider.dart';
import 'package:planify_app/providers/theme_provider.dart';
import 'package:planify_app/providers/focus_timer_provider.dart';
import 'package:planify_app/core/utils/firebase_error_message.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _search = '';

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final tasksAsync = ref.watch(tasksProvider);
    final notesAsync = ref.watch(notesProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final searchAsync = ref.watch(globalSearchProvider(_search));
    ref.watch(themeModeProvider);
    final focusState = ref.watch(focusTimerProvider);
    final isFocusActive =
        focusState.isRunning || (focusState.remaining < focusState.total);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLow,
      body: CustomScrollView(
        slivers: [
          // ── Top App Bar ────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            backgroundColor: AppTheme.surfaceContainerLow.withAlpha(204),
            elevation: 0,
            title: Row(
              children: [
                Text('Planify',
                    style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                        letterSpacing: -0.5)),
              ],
            ),
            actions: [
              IconButton(
                icon:
                    const Icon(Icons.search_rounded, color: AppTheme.onSurface),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded,
                    color: AppTheme.onSurface),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: AppTheme.surfaceContainerLowest,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: AppTheme.primaryContainer,
                              child: Text(user?.initials ?? '?',
                                  style: GoogleFonts.manrope(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.onPrimaryContainer)),
                            ),
                            const SizedBox(height: 16),
                            Text(user?.fullName ?? 'User',
                                style: Theme.of(context).textTheme.titleLarge),
                            if (user?.email != null) ...[
                              const SizedBox(height: 4),
                              Text(user!.email,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: AppTheme.onSurfaceVariant)),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ref.read(authProvider.notifier).logout();
                                },
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Logout'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.errorContainer,
                                  foregroundColor: AppTheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryContainer,
                  child: Text(user?.initials ?? '?',
                      style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onPrimaryContainer)),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Hero greeting ──────────────────────────────────────────────
                Text('${_greeting()},',
                    style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceVariant)),
                Text(user?.fullName.split(' ').first ?? 'there',
                    style: GoogleFonts.manrope(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                        letterSpacing: -1.5)),
                if (kEnableOfflineTestingMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Testing build: sign-in disabled',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                tasksAsync.when(
                  data: (tasks) {
                    final pending = tasks.where((t) => !t.isComplete).length;
                    return Text(
                      pending == 0
                          ? 'All clear for today! 🎉'
                          : 'You have $pending tasks to wrap up today.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppTheme.onSurfaceVariant),
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    hintText: 'Search tasks, notes, events, projects...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    fillColor: AppTheme.surfaceContainerHigh,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_search.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Search Results',
                    child: searchAsync.when(
                      data: (results) {
                        final items = [
                          ...results.tasks,
                          ...results.notes,
                          ...results.events,
                          ...results.projects,
                        ];
                        if (items.isEmpty) {
                          return _emptyState(
                              context, 'No matches', 'Try another keyword.');
                        }
                        return Column(
                          children: items.take(8).map((item) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                switch (item.type) {
                                  'task' => Icons.checklist_rounded,
                                  'note' => Icons.description_outlined,
                                  'event' => Icons.calendar_today_outlined,
                                  _ => Icons.folder_outlined,
                                },
                              ),
                              title: Text(item.title),
                              subtitle: Text(item.type.toUpperCase()),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const _Shimmer(),
                      error: (e, _) => _errorState(
                        context,
                        ref,
                        e,
                        onRetry: () =>
                            ref.invalidate(globalSearchProvider(_search)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── AI Smart Insight ───────────────────────────────────────────
                _SectionCard(
                  title: 'Smart Insight',
                  trailing: const Icon(Icons.auto_awesome_rounded,
                      color: AppTheme.primary, size: 20),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final insightAsync = ref.watch(smartInsightProvider);
                      return insightAsync.when(
                        data: (insight) => Text(
                          insight,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                        ),
                        loading: () => const _Shimmer(),
                        error: (e, _) => Text(
                          'Could not generate insight right now.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.error,
                                  ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                _SectionCard(
                  title: 'Quick Actions',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => context.go('/tasks'),
                        icon: const Icon(Icons.add_task_rounded, size: 16),
                        label: const Text('Add task'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/focus'),
                        icon: const Icon(Icons.bolt_rounded, size: 16),
                        label: const Text('Start focus'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.go('/notes'),
                        icon: const Icon(Icons.note_add_outlined, size: 16),
                        label: const Text('New note'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.go('/calendar'),
                        icon: const Icon(Icons.event_available_outlined,
                            size: 16),
                        label: const Text('Add event'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.go('/reminders'),
                        icon: const Icon(Icons.alarm_add_rounded, size: 16),
                        label: const Text('Set reminder'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.go('/workspace'),
                        icon: const Icon(Icons.grid_view_outlined, size: 16),
                        label: const Text('Workspace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Focus Mode CTA or Active Block ─────────────────────────────
                if (isFocusActive)
                  GestureDetector(
                    onTap: () => context.push('/focus'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.timer_rounded,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${focusState.phase.name.toUpperCase()} IN PROGRESS',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w800)),
                                Text(focusState.displayTime,
                                    style: GoogleFonts.manrope(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.onPrimaryContainer)),
                              ],
                            ),
                          ),
                          Icon(
                            focusState.isRunning
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: AppTheme.primary,
                            size: 32,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => context.push('/focus'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDim],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(60),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Text('Start Focus Mode',
                              style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white54, size: 16),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 28),

                // ── Next Up ────────────────────────────────────────────────────
                _SectionCard(
                  title: 'Next Up',
                  badge: 'Today',
                  child: summaryAsync.when(
                    data: (summary) {
                      final pending = summary.todayTasks.take(4).toList();
                      if (pending.isEmpty) {
                        return _emptyState(context, 'All done! 🎉',
                            'No pending tasks for today.');
                      }
                      return Column(
                        children: pending
                            .map((t) => _DashboardTaskRow(task: t))
                            .toList(),
                      );
                    },
                    loading: () => const _Shimmer(),
                    error: (e, _) =>
                        _buildLocalNextUp(context, ref, tasksAsync, e),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Recent Notes ───────────────────────────────────────────────
                _SectionCard(
                  title: 'Recent Notes',
                  trailing: TextButton(
                    onPressed: () => context.go('/notes'),
                    child: Text('View all',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                color: AppTheme.secondary,
                                fontWeight: FontWeight.w700)),
                  ),
                  child: summaryAsync.when(
                    data: (summary) {
                      final recent = summary.recentNotes.take(2).toList();
                      if (recent.isEmpty) {
                        return _emptyState(context, 'No notes yet',
                            'Tap + to create your first note.');
                      }
                      return GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        children: recent
                            .map((n) => _SimpleNoteCard(
                                  title: n.title,
                                  updatedAt: n.updatedAt,
                                  isPinned: n.isPinned,
                                ))
                            .toList(),
                      );
                    },
                    loading: () => const _Shimmer(),
                    error: (e, _) =>
                        _buildLocalRecentNotes(context, ref, notesAsync, e),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Upcoming Calendar ──────────────────────────────────────────
                _SectionCard(
                  title: 'Calendar',
                  trailing: const Icon(Icons.calendar_today_outlined,
                      color: AppTheme.onSurfaceVariant, size: 20),
                  child: summaryAsync.when(
                    data: (summary) {
                      final upcoming = summary.upcomingEvents.take(3).toList();
                      if (upcoming.isEmpty) {
                        return _emptyState(context, 'No upcoming events',
                            'Your schedule is clear.');
                      }
                      return Column(
                        children: upcoming
                            .map((e) => _SimpleEventRow(
                                  title: e.title,
                                  startTime: e.startTime,
                                  endTime: e.endTime,
                                  allDay: e.allDay,
                                ))
                            .toList(),
                      );
                    },
                    loading: () => const _Shimmer(),
                    error: (e, _) =>
                        _buildLocalCalendar(context, ref, eventsAsync, e),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Upcoming Reminders ─────────────────────────────────────
                _SectionCard(
                  title: 'Reminders',
                  trailing: IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: AppTheme.onSurfaceVariant, size: 20),
                    onPressed: () => context.go('/reminders'),
                  ),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final remindersAsync = ref.watch(remindersProvider);
                      return remindersAsync.when(
                        data: (reminders) {
                          final upcoming = reminders
                              .where((r) =>
                                  !r.isCompleted &&
                                  r.reminderTime.isAfter(DateTime.now()))
                              .take(3)
                              .toList();
                          if (upcoming.isEmpty) {
                            return _emptyState(context, 'No reminders',
                                'Set reminders to stay on track.');
                          }
                          return Column(
                            children: upcoming.map((r) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    const Icon(
                                        Icons.notifications_active_outlined,
                                        size: 18,
                                        color: AppTheme.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(r.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    Text(
                                      DateFormat('MMM d, h:mm a')
                                          .format(r.reminderTime),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const _Shimmer(),
                        error: (e, _) => _errorState(context, ref, e),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildLocalNextUp(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TaskModel>> tasksAsync,
    Object summaryError,
  ) {
    return tasksAsync.when(
      data: (tasks) {
        final now = DateTime.now();
        final pending = tasks
            .where((task) =>
                !task.isComplete &&
                task.deadline != null &&
                task.deadline!.year == now.year &&
                task.deadline!.month == now.month &&
                task.deadline!.day == now.day)
            .take(4)
            .toList();

        if (pending.isEmpty) {
          return _emptyState(
            context,
            'All done! 🎉',
            'No pending tasks for today.',
          );
        }

        return Column(
          children:
              pending.map((task) => _DashboardTaskRow(task: task)).toList(),
        );
      },
      loading: () => const _Shimmer(),
      error: (_, __) => _errorState(context, ref, summaryError),
    );
  }

  Widget _buildLocalRecentNotes(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<NoteModel>> notesAsync,
    Object summaryError,
  ) {
    return notesAsync.when(
      data: (notes) {
        final recent = [...notes]..sort((a, b) {
            if (a.isPinned == b.isPinned) {
              return b.updatedAt.compareTo(a.updatedAt);
            }
            return a.isPinned ? -1 : 1;
          });

        if (recent.isEmpty) {
          return _emptyState(
            context,
            'No notes yet',
            'Tap + to create your first note.',
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: recent
              .take(2)
              .map((note) => _SimpleNoteCard(
                    title: note.title,
                    updatedAt: note.updatedAt,
                    isPinned: note.isPinned,
                  ))
              .toList(),
        );
      },
      loading: () => const _Shimmer(),
      error: (_, __) => _errorState(context, ref, summaryError),
    );
  }

  Widget _buildLocalCalendar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<EventModel>> eventsAsync,
    Object summaryError,
  ) {
    return eventsAsync.when(
      data: (events) {
        final now = DateTime.now();
        final upcoming = events
            .where((event) => event.endTime.isAfter(now))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        if (upcoming.isEmpty) {
          return _emptyState(
            context,
            'No upcoming events',
            'Your schedule is clear.',
          );
        }

        return Column(
          children: upcoming
              .take(3)
              .map((event) => _SimpleEventRow(
                    title: event.title,
                    startTime: event.startTime,
                    endTime: event.endTime,
                    allDay: event.allDay,
                  ))
              .toList(),
        );
      },
      loading: () => const _Shimmer(),
      error: (_, __) => _errorState(context, ref, summaryError),
    );
  }

  Widget _errorState(
    BuildContext context,
    WidgetRef ref,
    Object error, {
    VoidCallback? onRetry,
  }) {
    final msg = planifyFirebaseErrorMessage(error);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.error)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed:
                onRetry ?? () => ref.invalidate(dashboardSummaryProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String? badge;
  final Widget? trailing;
  final Widget child;

  const _SectionCard(
      {required this.title, required this.child, this.badge, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppTheme.primaryContainer.withAlpha(80),
                      borderRadius: BorderRadius.circular(100)),
                  child: Text(badge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800)),
                ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
          3,
          (_) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 52,
                decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16)),
              )),
    );
  }
}

class _DashboardTaskRow extends StatelessWidget {
  final dynamic task;
  const _DashboardTaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            task.isComplete
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            size: 20,
            color: task.isComplete ? AppTheme.primary : AppTheme.outlineVariant,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(task.title)),
          if (task.deadline != null)
            Text(
              DateFormat('h:mm a').format(task.deadline!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _SimpleNoteCard extends StatelessWidget {
  final String title;
  final DateTime updatedAt;
  final bool isPinned;
  const _SimpleNoteCard({
    required this.title,
    required this.updatedAt,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPinned) const Icon(Icons.push_pin_rounded, size: 14),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text(DateFormat('MMM d').format(updatedAt)),
          ],
        ),
      );
}

class _SimpleEventRow extends StatelessWidget {
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final bool allDay;
  const _SimpleEventRow({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.allDay,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(child: Text(title)),
            Text(allDay
                ? 'All day'
                : '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}'),
          ],
        ),
      );
}
