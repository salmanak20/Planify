import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:planify_app/core/theme/app_theme.dart';
import 'package:planify_app/core/utils/app_snackbar.dart';
import 'package:planify_app/data/models/reminder_model.dart';
import 'package:planify_app/providers/reminders_provider.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _trackReminderAction(Future<void> action, String failureMessage) {
    unawaited(action.catchError((_) {
      showPlanifySnackBar(failureMessage);
    }));
  }

  void _deleteReminder(int id) {
    _trackReminderAction(
      ref.read(remindersProvider.notifier).delete(id),
      'Could not delete reminder',
    );
    showPlanifySnackBar('Reminder deleted');
  }

  Future<void> _showReminderSheet({ReminderModel? reminder}) async {
    final titleCtrl = TextEditingController(text: reminder?.title ?? '');
    final notesCtrl = TextEditingController(text: reminder?.notes ?? '');
    var selectedTime = reminder?.reminderTime ?? _defaultReminderTime();
    var repeat = reminder?.repeat ?? ReminderRepeat.none;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle bar ───────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  reminder == null ? 'New Reminder' : 'Edit Reminder',
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Title ────────────────────────────────────────────────────
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Remind me to...',
                    prefixIcon: Icon(Icons.notifications_active_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Notes ────────────────────────────────────────────────────
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Date & Time ──────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: ctx,
                        initialDate: selectedTime,
                        firstDate: reminder == null
                            ? DateTime.now()
                            : DateTime.now()
                                .subtract(const Duration(days: 3650)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (pickedDate == null || !ctx.mounted) return;
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(selectedTime),
                      );
                      if (pickedTime == null) return;
                      setSheetState(() {
                        selectedTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },
                    icon: const Icon(Icons.schedule_outlined, size: 18),
                    label: Text(
                      DateFormat('EEE, MMM d · h:mm a').format(selectedTime),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Repeat ───────────────────────────────────────────────────
                Text(
                  'Repeat',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ReminderRepeat.values.map((option) {
                    final isSelected = repeat == option;
                    return GestureDetector(
                      onTap: () => setSheetState(() => repeat = option),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryContainer
                              : AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          option.label,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: isSelected
                                        ? AppTheme.onPrimaryContainer
                                        : AppTheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ── Submit ───────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      if (repeat == ReminderRepeat.none &&
                          !selectedTime.isAfter(DateTime.now())) {
                        showPlanifySnackBar(
                          'Pick a future time for this reminder',
                        );
                        return;
                      }
                      final notes = notesCtrl.text.trim();
                      if (reminder == null) {
                        _trackReminderAction(
                          ref.read(remindersProvider.notifier).create(
                                title: title,
                                notes: notes.isEmpty ? null : notes,
                                reminderTime: selectedTime,
                                repeat: repeat,
                              ),
                          'Could not create reminder',
                        );
                        showPlanifySnackBar(
                          'Reminder set for ${DateFormat('MMM d, h:mm a').format(selectedTime)}',
                        );
                      } else {
                        _trackReminderAction(
                          ref.read(remindersProvider.notifier).update(
                            reminder.id,
                            {
                              'title': title,
                              'notes': notes.isEmpty ? null : notes,
                              'reminder_time': selectedTime.toIso8601String(),
                              'repeat': repeat.apiValue,
                            },
                          ),
                          'Could not update reminder',
                        );
                        showPlanifySnackBar('Reminder updated');
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.alarm_add_rounded,
                        color: Colors.white),
                    label: Text(
                      reminder == null ? 'Set Reminder' : 'Update Reminder',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DateTime _defaultReminderTime() {
    final now = DateTime.now();
    final candidate =
        DateTime(now.year, now.month, now.day, now.hour, now.minute)
            .add(const Duration(minutes: 30));
    return candidate;
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLow,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReminderSheet(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.alarm_add_rounded),
        label: Text(
          'Set Reminder',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppTheme.surfaceContainerLow.withAlpha(204),
            elevation: 0,
            title: Text(
              'Reminders',
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelStyle:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.onSurfaceVariant,
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
          SliverFillRemaining(
            child: remindersAsync.when(
              data: (reminders) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _RemindersList(
                      reminders: reminders.where((r) => !r.isCompleted).toList()
                        ..sort(
                            (a, b) => a.reminderTime.compareTo(b.reminderTime)),
                      emptyTitle: 'No upcoming reminders',
                      emptySubtitle: 'Tap + to set your first reminder.',
                      onToggle: (id) => ref
                          .read(remindersProvider.notifier)
                          .toggleComplete(id),
                      onEdit: (reminder) =>
                          _showReminderSheet(reminder: reminder),
                      onDelete: _deleteReminder,
                    ),
                    _RemindersList(
                      reminders: reminders.where((r) => r.isCompleted).toList()
                        ..sort(
                            (a, b) => b.reminderTime.compareTo(a.reminderTime)),
                      emptyTitle: 'No completed reminders',
                      emptySubtitle: 'Completed reminders will show here.',
                      onToggle: (id) => ref
                          .read(remindersProvider.notifier)
                          .toggleComplete(id),
                      onEdit: (reminder) =>
                          _showReminderSheet(reminder: reminder),
                      onDelete: _deleteReminder,
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reminder list ────────────────────────────────────────────────────────────

class _RemindersList extends StatelessWidget {
  const _RemindersList({
    required this.reminders,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ReminderModel> reminders;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<int> onToggle;
  final ValueChanged<ReminderModel> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: AppTheme.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                emptySubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group by date
    final grouped = <String, List<ReminderModel>>{};
    for (final reminder in reminders) {
      final key = _dateGroupKey(reminder.reminderTime);
      grouped.putIfAbsent(key, () => []).add(reminder);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(
                entry.key,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...entry.value.map(
              (reminder) => _ReminderCard(
                reminder: reminder,
                onToggle: () => onToggle(reminder.id),
                onEdit: () => onEdit(reminder),
                onDelete: () => onDelete(reminder.id),
              ),
            ),
          ],
        );
      },
    );
  }

  String _dateGroupKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'TODAY';
    if (date == today.add(const Duration(days: 1))) return 'TOMORROW';
    if (date.isBefore(today)) return 'PAST DUE';

    final diff = date.difference(today).inDays;
    if (diff <= 7) return DateFormat('EEEE').format(dt).toUpperCase();
    return DateFormat('MMMM d').format(dt).toUpperCase();
  }
}

// ── Reminder card widget ────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ReminderModel reminder;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  bool get _isPastDue =>
      !reminder.isCompleted && reminder.reminderTime.isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final borderColor = _isPastDue
        ? AppTheme.error
        : reminder.isCompleted
            ? AppTheme.secondary
            : AppTheme.primary;

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.error.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: borderColor.withAlpha(14),
          borderRadius: BorderRadius.circular(20),
          border: Border(left: BorderSide(color: borderColor, width: 4)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // ── Checkbox circle ─────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: reminder.isCompleted
                        ? AppTheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: reminder.isCompleted
                          ? AppTheme.primary
                          : AppTheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: reminder.isCompleted
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),

                // ── Content ─────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: reminder.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: reminder.isCompleted
                                  ? AppTheme.onSurfaceVariant
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: _isPastDue
                                ? AppTheme.error
                                : AppTheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('h:mm a').format(reminder.reminderTime),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _isPastDue
                                          ? AppTheme.error
                                          : AppTheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                          if (reminder.repeat != ReminderRepeat.none) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.repeat_rounded,
                                      size: 12,
                                      color: AppTheme.onSurfaceVariant),
                                  const SizedBox(width: 3),
                                  Text(
                                    reminder.repeat.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppTheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (reminder.notes != null &&
                          reminder.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          reminder.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
