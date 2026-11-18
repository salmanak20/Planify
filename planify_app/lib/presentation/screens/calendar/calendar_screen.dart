import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:planify_app/core/theme/app_theme.dart';
import 'package:planify_app/core/utils/app_snackbar.dart';
import 'package:planify_app/data/models/event_model.dart';
import 'package:planify_app/data/models/project_model.dart';
import 'package:planify_app/providers/events_provider.dart';
import 'package:planify_app/providers/projects_provider.dart';
import 'package:planify_app/providers/tasks_provider.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const List<_ReminderOption> _reminderOptions = [
    _ReminderOption(label: '10 min before', offset: Duration(minutes: 10)),
    _ReminderOption(label: '15 min before', offset: Duration(minutes: 15)),
    _ReminderOption(label: '30 min before', offset: Duration(minutes: 30)),
    _ReminderOption(label: '1 hour before', offset: Duration(hours: 1)),
  ];

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.week;

  DateTime _initialStartForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final defaultStart = dayStart.add(const Duration(hours: 9));
    final now = DateTime.now();

    if (!_isSameCalendarDay(dayStart, now)) {
      return defaultStart;
    }

    final candidate = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 30));

    if (!_isSameCalendarDay(candidate, dayStart)) {
      return DateTime(now.year, now.month, now.day, now.hour, now.minute);
    }

    return candidate.isAfter(defaultStart) ? candidate : defaultStart;
  }

  String _eventCreatedMessage(DateTime start, DateTime? reminderAt) {
    if (reminderAt == null) {
      return 'Event created';
    }

    final now = DateTime.now();
    final scheduledAt = reminderAt.isAfter(now)
        ? reminderAt
        : start.isAfter(now)
            ? start
            : null;

    if (scheduledAt == null) {
      return 'Event created. Reminder was skipped because the event time has passed.';
    }

    return 'Event created. Reminder set for ${DateFormat('MMM d, h:mm a').format(scheduledAt)}';
  }

  bool _isSameCalendarDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  void _trackCalendarAction(Future<void> action, String failureMessage) {
    unawaited(action.catchError((_) {
      showPlanifySnackBar(failureMessage);
    }));
  }

  void _deleteEvent(EventModel event) {
    _trackCalendarAction(
      ref.read(eventsProvider.notifier).delete(event.id),
      'Could not delete event',
    );
    showPlanifySnackBar('Event deleted');
  }

  Future<void> _showEventSheet({EventModel? event}) async {
    final titleCtrl = TextEditingController(text: event?.title ?? '');
    final descCtrl = TextEditingController(text: event?.description ?? '');
    final locationCtrl = TextEditingController(text: event?.location ?? '');
    final projects =
        ref.read(projectsProvider).valueOrNull ?? const <ProjectModel>[];
    var color = event?.color ?? '#435f92';
    var start = event?.startTime ?? _initialStartForDay(_selectedDay);
    var end = event?.endTime ?? start.add(const Duration(hours: 1));
    Duration? reminderOffset = event == null
        ? const Duration(minutes: 10)
        : event.reminderAt == null
            ? null
            : event.startTime.difference(event.reminderAt!);
    int? projectId = event?.projectId;
    var allDay = event?.allDay ?? false;
    var repeat = event?.repeat ?? EventRepeat.none;
    int repeatInterval = event?.repeatInterval ?? 1;
    List<int> repeatWeekdays = [...(event?.repeatWeekdays ?? const <int>[])];
    DateTime? recurrenceEnd = event?.recurrenceEnd;

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
                Text(
                  event == null ? 'New Event' : 'Edit Event',
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Event title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Location (optional)',
                  ),
                ),
                if (projects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: projectId,
                    decoration: const InputDecoration(
                      hintText: 'Attach to project',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No project'),
                      ),
                      ...projects.map(
                        (project) => DropdownMenuItem<int?>(
                          value: project.id,
                          child: Text(project.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() => projectId = value);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Color',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: ['#435f92', '#57634c', '#7c5831', '#a83836'].map(
                    (option) {
                      final swatch = _colorFromHex(option, AppTheme.primary);
                      return GestureDetector(
                        onTap: () => setSheetState(() => color = option),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: swatch,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == option
                                  ? AppTheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  value: allDay,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All day'),
                  onChanged: (value) {
                    setSheetState(() {
                      allDay = value;
                      if (allDay) {
                        start = DateTime(
                          start.year,
                          start.month,
                          start.day,
                        );
                        end = start.add(const Duration(days: 1));
                      }
                    });
                  },
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: ctx,
                        initialDate: start,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (pickedDate == null || !ctx.mounted) return;
                      if (allDay) {
                        setSheetState(() {
                          start = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                          );
                          end = start.add(const Duration(days: 1));
                        });
                        return;
                      }

                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(start),
                      );
                      if (pickedTime == null) return;

                      setSheetState(() {
                        start = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                        if (!end.isAfter(start)) {
                          end = start.add(const Duration(hours: 1));
                        }
                      });
                    },
                    icon: const Icon(Icons.schedule_outlined, size: 16),
                    label: Text(
                      allDay
                          ? 'Starts ${DateFormat('MMM d').format(start)}'
                          : 'Starts ${DateFormat('MMM d, h:mm a').format(start)}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: allDay
                        ? null
                        : () async {
                            final pickedDate = await showDatePicker(
                              context: ctx,
                              initialDate: end,
                              firstDate: start,
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (pickedDate == null || !ctx.mounted) return;
                            final pickedTime = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(end),
                            );
                            if (pickedTime == null) return;

                            setSheetState(() {
                              end = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                              if (!end.isAfter(start)) {
                                end = start.add(const Duration(hours: 1));
                              }
                            });
                          },
                    icon: const Icon(Icons.event_available_outlined, size: 16),
                    label: Text(
                      'Ends ${DateFormat('MMM d, h:mm a').format(end)}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                  children: [
                    _RepeatChip(
                      label: 'Once',
                      selected: repeat == EventRepeat.none,
                      onTap: () =>
                          setSheetState(() => repeat = EventRepeat.none),
                    ),
                    _RepeatChip(
                      label: 'Daily',
                      selected: repeat == EventRepeat.daily,
                      onTap: () =>
                          setSheetState(() => repeat = EventRepeat.daily),
                    ),
                    _RepeatChip(
                      label: 'This week',
                      selected: repeat == EventRepeat.weekly,
                      onTap: () =>
                          setSheetState(() => repeat = EventRepeat.weekly),
                    ),
                    _RepeatChip(
                      label: 'Monthly',
                      selected: repeat == EventRepeat.monthly,
                      onTap: () =>
                          setSheetState(() => repeat = EventRepeat.monthly),
                    ),
                  ],
                ),
                if (repeat != EventRepeat.none) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Repeat every:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: repeatInterval > 1
                            ? () => setSheetState(() => repeatInterval--)
                            : null,
                      ),
                      Text(
                        '$repeatInterval ${repeat == EventRepeat.daily ? (repeatInterval == 1 ? 'day' : 'days') : repeat == EventRepeat.weekly ? (repeatInterval == 1 ? 'week' : 'weeks') : (repeatInterval == 1 ? 'month' : 'months')}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setSheetState(() => repeatInterval++),
                      ),
                    ],
                  ),
                  if (repeat == EventRepeat.weekly) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (int i = 1; i <= 7; i++)
                          ChoiceChip(
                            label: Text(
                                ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i - 1]),
                            selected: repeatWeekdays.contains(i),
                            onSelected: (val) {
                              setSheetState(() {
                                if (val) {
                                  repeatWeekdays.add(i);
                                } else {
                                  repeatWeekdays.remove(i);
                                }
                              });
                            },
                          )
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: ctx,
                          initialDate: start.add(const Duration(days: 1)),
                          firstDate: start,
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (pickedDate != null) {
                          setSheetState(() => recurrenceEnd = pickedDate);
                        } else if (recurrenceEnd != null) {
                          // Allow clearing it if they cancel? No, let's keep it simple
                        }
                      },
                      onLongPress: () =>
                          setSheetState(() => recurrenceEnd = null),
                      icon: const Icon(Icons.event_busy_outlined, size: 16),
                      label: Text(recurrenceEnd == null
                          ? 'Ends never (Long press to clear if set)'
                          : 'Ends ${DateFormat('MMM d, yyyy').format(recurrenceEnd!)}'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('No reminder'),
                      selected: reminderOffset == null,
                      onSelected: (_) {
                        setSheetState(() => reminderOffset = null);
                      },
                    ),
                    ..._reminderOptions.map(
                      (option) => FilterChip(
                        label: Text(option.label),
                        selected: reminderOffset == option.offset,
                        onSelected: (_) {
                          setSheetState(() => reminderOffset = option.offset);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      final description = descCtrl.text.trim();
                      final location = locationCtrl.text.trim();
                      final reminderAt = reminderOffset == null
                          ? null
                          : start.subtract(reminderOffset!);
                      if (event == null) {
                        _trackCalendarAction(
                          ref.read(eventsProvider.notifier).create(
                                title: title,
                                description:
                                    description.isEmpty ? null : description,
                                location: location.isEmpty ? null : location,
                                color: color,
                                projectId: projectId,
                                startTime: start,
                                endTime: end,
                                reminderAt: reminderAt,
                                allDay: allDay,
                                repeat: repeat,
                                repeatInterval: repeatInterval,
                                repeatWeekdays: List<int>.from(repeatWeekdays),
                                recurrenceEnd: recurrenceEnd,
                              ),
                          'Could not create event',
                        );
                        showPlanifySnackBar(
                          _eventCreatedMessage(start, reminderAt),
                        );
                      } else {
                        _trackCalendarAction(
                          ref.read(eventsProvider.notifier).update(
                            event.id,
                            {
                              'title': title,
                              'description':
                                  description.isEmpty ? null : description,
                              'location': location.isEmpty ? null : location,
                              'color': color,
                              'project_id': projectId,
                              'start_time': start.toIso8601String(),
                              'end_time': end.toIso8601String(),
                              'reminder_at': reminderAt?.toIso8601String(),
                              'all_day': allDay,
                              'repeat': repeat.apiValue,
                              'repeat_interval': repeatInterval,
                              'repeat_weekdays': List<int>.from(repeatWeekdays),
                              'recurrence_end':
                                  recurrenceEnd?.toIso8601String(),
                            },
                          ),
                          'Could not update event',
                        );
                        showPlanifySnackBar('Event updated');
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      event == null ? 'Add Event' : 'Update Event',
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

  Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final normalized = hex.replaceAll('#', '');
    if (normalized.length != 6) return fallback;
    return Color(int.parse('FF$normalized', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final eventsNotifier = ref.read(eventsProvider.notifier);
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLow,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEventSheet(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Event',
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
              'Calendar',
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime.now();
                    _selectedDay = DateTime.now();
                  });
                },
                child: const Text('Today'),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<CalendarFormat>(
                  segments: const [
                    ButtonSegment(
                      value: CalendarFormat.week,
                      label: Text('Week'),
                      icon: Icon(Icons.view_week_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: CalendarFormat.month,
                      label: Text('Month'),
                      icon: Icon(Icons.calendar_view_month_outlined, size: 16),
                    ),
                  ],
                  selected: {_format},
                  onSelectionChanged: (selection) {
                    setState(() => _format = selection.first);
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: eventsAsync.when(
                data: (_) => TableCalendar(
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2028, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  calendarFormat: _format,
                  daysOfWeekHeight: 28,
                  onFormatChanged: (format) {
                    setState(() => _format = format);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDay = focusedDay);
                  },
                  eventLoader: (day) {
                    final events = eventsNotifier.eventsForDay(day);
                    final tasks = tasksAsync.valueOrNull
                            ?.where((t) =>
                                t.deadline != null &&
                                isSameDay(t.deadline, day))
                            .toList() ??
                        [];
                    return [...events, ...tasks];
                  },
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    outsideDaysVisible: false,
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    dowBuilder: (context, day) => Center(
                      child: Text(
                        DateFormat('EEE').format(day),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                ),
                loading: () => const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SizedBox(
                  height: 100,
                  child: Center(child: Text('$error')),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            sliver: eventsAsync.when(
              data: (_) {
                final dayEvents = eventsNotifier.eventsForDay(_selectedDay);
                return SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      Text(
                        DateFormat('EEEE, MMMM d').format(_selectedDay),
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (dayEvents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: Text('No events this day')),
                        )
                      else
                        ...dayEvents.map(
                          (event) => _EventCard(
                            event: event,
                            onEdit: () => _showEventSheet(event: event),
                            onDelete: () => _deleteEvent(event),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Task Deadlines',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 8),
                      tasksAsync.when(
                        data: (tasks) {
                          final dayTasks = tasks
                              .where((task) =>
                                  task.deadline != null &&
                                  task.deadline!.year == _selectedDay.year &&
                                  task.deadline!.month == _selectedDay.month &&
                                  task.deadline!.day == _selectedDay.day)
                              .toList();
                          if (dayTasks.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No task deadlines for this day'),
                            );
                          }
                          return Column(
                            children: dayTasks
                                .map(
                                  (task) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      task.isComplete
                                          ? Icons.check_circle_rounded
                                          : Icons
                                              .radio_button_unchecked_rounded,
                                    ),
                                    title: Text(task.title),
                                    subtitle: task.deadline == null
                                        ? null
                                        : Text(DateFormat('h:mm a')
                                            .format(task.deadline!)),
                                  ),
                                )
                                .toList(),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final controller = TextEditingController();
                          final created = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Create task from this day'),
                              content: TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  hintText: 'Task title',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(
                                      ctx, controller.text.trim()),
                                  child: const Text('Create'),
                                ),
                              ],
                            ),
                          );
                          if (created == null || created.isEmpty) return;
                          _trackCalendarAction(
                            ref
                                .read(tasksProvider.notifier)
                                .createFromCalendarDay(
                                  title: created,
                                  day: _selectedDay,
                                ),
                            'Could not create task',
                          );
                          showPlanifySnackBar('Task created');
                        },
                        icon: const Icon(Icons.add_task_rounded),
                        label: const Text('Create task from day'),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Center(child: Text('$error')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepeatChip extends StatelessWidget {
  const _RepeatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryContainer
              : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? AppTheme.onPrimaryContainer
                    : AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _ReminderOption {
  const _ReminderOption({
    required this.label,
    required this.offset,
  });

  final String label;
  final Duration offset;
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final EventModel event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final normalized = hex.replaceAll('#', '');
    if (normalized.length != 6) return fallback;
    return Color(int.parse('FF$normalized', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _colorFromHex(event.color, AppTheme.primary);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: borderColor.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.allDay
                      ? 'All day'
                      : '${DateFormat('h:mm a').format(event.startTime)} - ${DateFormat('h:mm a').format(event.endTime)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                ),
                if (event.repeat != EventRepeat.none) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      event.repeat.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppTheme.onSurfaceVariant,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.onSurfaceVariant,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
