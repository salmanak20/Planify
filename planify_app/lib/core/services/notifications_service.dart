import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:planify_app/data/datasources/cache_keys.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/data/models/event_model.dart';
import 'package:planify_app/data/models/reminder_model.dart';
import 'package:planify_app/data/models/task_model.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationsService {
  NotificationsService._();

  static final NotificationsService instance = NotificationsService._();
  static const MethodChannel _timezoneChannel =
      MethodChannel('planify/device_timezone');
  static const int _recurringSlotCount = 16;
  static const Duration _eventSchedulingHorizon = Duration(days: 90);
  static const int _focusStatusNotificationId = 400000;
  static const int _focusCompletionNotificationId = 400001;
  static const int _notificationRangeSize = 100000000;
  static const int _maxAndroidNotificationId = 0x7fffffff;
  static const int _taskIncomingBase = 100000000;
  static const int _taskDeadlineBase = 200000000;
  static const int _eventIncomingBase = 300000000;
  static const int _eventStartBase = 400000000;
  static const int _eventRecurringIncomingBase = 500000000;
  static const int _eventRecurringStartBase = 600000000;
  static const int _standaloneReminderBase = 700000000;
  static const int _standaloneRecurringReminderBase = 800000000;
  static final Int32List _insistentNotificationFlags =
      Int32List.fromList(<int>[4]);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;

  static const _incomingAndroidDetails = AndroidNotificationDetails(
    'planify_incoming_reminders_v2',
    'Planify reminders',
    channelDescription: 'Upcoming task, reminder, and calendar alerts',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('reminder'),
    category: AndroidNotificationCategory.reminder,
    audioAttributesUsage: AudioAttributesUsage.notificationEvent,
  );

  static final _alarmAndroidDetails = AndroidNotificationDetails(
    'planify_deadline_alarms_v2',
    'Planify deadline alarms',
    channelDescription:
        'Alarm-style alerts when tasks, reminders, and events are due',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    sound: const RawResourceAndroidNotificationSound('reminder'),
    category: AndroidNotificationCategory.alarm,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    additionalFlags: _insistentNotificationFlags,
  );

  static const _incomingNotificationDetails = NotificationDetails(
    android: _incomingAndroidDetails,
    iOS: DarwinNotificationDetails(sound: 'reminder.wav'),
  );

  static final _alarmNotificationDetails = NotificationDetails(
    android: _alarmAndroidDetails,
    iOS: const DarwinNotificationDetails(sound: 'reminder.wav'),
  );

  static const _focusStatusDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'planify_focus_status',
      'Planify focus status',
      channelDescription: 'Focus mode status updates for Planify',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _focusCompletionDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'planify_focus_alerts_v2',
      'Planify focus alerts',
      channelDescription: 'Focus mode completion alerts for Planify',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('timer_done'),
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
    iOS: DarwinNotificationDetails(sound: 'timer_done.wav'),
  );

  Future<void> initialize() async {
    if (_initialized) return;
    final runningInitialization = _initializing;
    if (runningInitialization != null) {
      await runningInitialization;
      return;
    }

    _initializing = _initialize();
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    await _configureLocalTimezone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_planify'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(settings);

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await initialize();
    await _requestPermissions();
  }

  Future<void> ensureReminderPermissions() async {
    await initialize();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notificationsEnabled =
        await _areAndroidNotificationsEnabled(androidPlugin);
    if (!notificationsEnabled) {
      final granted =
          await androidPlugin?.requestNotificationsPermission() ?? false;
      if (!granted) {
        throw const NotificationSchedulingException(
          'Notifications are disabled for Planify.',
        );
      }
    }
    await _requestExactAlarmPermissionIfNeeded(androidPlugin);

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await _requestExactAlarmPermissionIfNeeded(androidPlugin);
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _requestExactAlarmPermissionIfNeeded(
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  ) async {
    try {
      final canScheduleExact =
          await androidPlugin?.canScheduleExactNotifications() ?? true;
      if (!canScheduleExact) {
        await androidPlugin?.requestExactAlarmsPermission();
      }
    } catch (_) {
      // Exact alarm permission falls back to inexact scheduling below.
    }
  }

  Future<bool> _areAndroidNotificationsEnabled(
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  ) async {
    try {
      return await androidPlugin?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> syncTasks(List<TaskModel> tasks) async {
    for (final task in tasks) {
      await syncTask(task);
    }
  }

  Future<void> syncTask(TaskModel task) async {
    await initialize();
    await cancelTaskReminder(task.id);
    final reminders = _buildTaskReminders(task);
    if (reminders.isEmpty) return;

    await ensureReminderPermissions();
    for (final reminder in reminders) {
      await _scheduleNotification(reminder);
    }
  }

  Future<void> cancelTaskReminder(int taskId) async {
    await initialize();
    await _cancelReminderIds([
      _taskIncomingReminderId(taskId),
      _taskDeadlineReminderId(taskId),
      _legacyTaskReminderId(taskId),
    ]);
  }

  Future<void> syncEvents(List<EventModel> events) async {
    for (final event in events) {
      await syncEvent(event);
    }
  }

  Future<void> syncReminders(List<ReminderModel> reminders) async {
    for (final reminder in reminders) {
      await syncReminder(reminder);
    }
  }

  Future<void> syncReminder(ReminderModel reminder) async {
    await initialize();
    await cancelReminder(reminder.id);
    final reminders = _buildStandaloneReminders(reminder);
    if (reminders.isEmpty) return;

    await ensureReminderPermissions();
    for (final r in reminders) {
      await _scheduleNotification(r);
    }
  }

  Future<void> cancelReminder(int reminderId) async {
    await initialize();
    await _cancelReminderIds([
      _standaloneReminderId(reminderId),
      _legacyStandaloneReminderId(reminderId),
      for (var slot = 0; slot < _recurringSlotCount; slot++)
        _standaloneRecurringReminderId(reminderId, slot),
    ]);
  }

  Future<void> syncEvent(EventModel event) async {
    await initialize();
    await cancelEventReminder(event.id);
    final reminders = _buildEventReminders(event);
    if (reminders.isEmpty) return;

    await ensureReminderPermissions();
    for (final reminder in reminders) {
      await _scheduleNotification(reminder);
    }
  }

  Future<void> cancelEventReminder(int eventId) async {
    await initialize();
    await _cancelReminderIds([
      _eventIncomingReminderId(eventId),
      _eventStartReminderId(eventId),
      _legacyEventReminderId(eventId),
      for (var slot = 0; slot < _recurringSlotCount; slot++) ...[
        _eventRecurringIncomingReminderId(eventId, slot),
        _eventRecurringStartReminderId(eventId, slot),
        _legacyEventRecurringReminderId(eventId, slot),
      ],
    ]);
  }

  Future<void> restoreCachedReminders({
    required String uid,
    required LocalCacheService cache,
  }) async {
    await initialize();
    final session = cache.captureSession(uid);
    final tasks = _readCachedTasks(cache, session);
    final events = _readCachedEvents(cache, session);
    final reminders = _readCachedReminders(cache, session);
    final results = await Future.wait([tasks, events, reminders]);
    final cachedTasks = results[0] as List<TaskModel>;
    final cachedEvents = results[1] as List<EventModel>;
    final cachedReminders = results[2] as List<ReminderModel>;

    await _prunePendingReminderRequests(
      activeReminderIds: {
        for (final task in cachedTasks)
          ..._buildTaskReminders(task).map((r) => r.id),
        for (final event in cachedEvents)
          ..._buildEventReminders(event).map((r) => r.id),
        for (final reminder in cachedReminders)
          ..._buildStandaloneReminders(reminder).map((r) => r.id),
      },
    );

    await syncTasks(cachedTasks);
    await syncEvents(cachedEvents);
    await syncReminders(cachedReminders);
  }

  Future<void> _scheduleNotification(_ScheduledReminder reminder) async {
    if (!reminder.scheduledAt.isAfter(DateTime.now())) return;

    final scheduleMode = await _resolveScheduleMode();
    await _plugin.cancel(reminder.id);
    await _plugin.zonedSchedule(
      reminder.id,
      reminder.title,
      reminder.body,
      tz.TZDateTime.from(reminder.scheduledAt.toLocal(), tz.local),
      reminder.details,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showFocusBackgroundStatus({
    required Duration remaining,
    String? taskTitle,
  }) async {
    await initialize();
    await ensureReminderPermissions();
    final label = _focusTaskLabel(taskTitle);
    final minutesLeft = remaining.inMinutes;
    final body = minutesLeft > 0
        ? '$label is still running. About $minutesLeft min left.'
        : '$label is still running in the background.';

    await _plugin.show(
      _focusStatusNotificationId,
      'Focus mode is active',
      body,
      _focusStatusDetails,
    );
  }

  Future<void> scheduleFocusSessionCompletion({
    required DateTime completesAt,
    String? taskTitle,
  }) async {
    await initialize();
    await _plugin.cancel(_focusCompletionNotificationId);
    if (!completesAt.isAfter(DateTime.now())) return;

    await ensureReminderPermissions();
    final scheduleMode = await _resolveScheduleMode();
    final label = _focusTaskLabel(taskTitle);

    await _plugin.zonedSchedule(
      _focusCompletionNotificationId,
      'Focus session complete',
      '$label has finished. Jump back into Planify when you are ready.',
      tz.TZDateTime.from(completesAt.toLocal(), tz.local),
      _focusCompletionDetails,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelFocusNotifications() async {
    await initialize();
    await _plugin.cancel(_focusStatusNotificationId);
    await _plugin.cancel(_focusCompletionNotificationId);
  }

  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canScheduleExact =
        await androidPlugin?.canScheduleExactNotifications() ?? false;
    return canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezoneId =
          await _timezoneChannel.invokeMethod<String>('getLocalTimezone');
      if (timezoneId != null && timezoneId.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(timezoneId));
        return;
      }
    } on MissingPluginException {
      // Non-Android platforms can fall back to the timezone package default.
    } catch (_) {
      // If the platform reports an unknown timezone, fall back below.
    }

    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<List<TaskModel>> _readCachedTasks(
    LocalCacheService cache,
    CacheSession session,
  ) async {
    final rawTasks = await cache.readJsonListForUser(
      session,
      CacheKeys.tasks(session.uid),
    );
    final tasks = <TaskModel>[];
    for (final item in rawTasks) {
      try {
        tasks.add(TaskModel.fromJson(item));
      } catch (_) {
        // Ignore corrupt cache entries so one bad record doesn't block reminders.
      }
    }
    return tasks;
  }

  Future<List<EventModel>> _readCachedEvents(
    LocalCacheService cache,
    CacheSession session,
  ) async {
    final rawEvents = await cache.readJsonListForUser(
      session,
      CacheKeys.events(session.uid),
    );
    final events = <EventModel>[];
    for (final item in rawEvents) {
      try {
        events.add(EventModel.fromJson(item));
      } catch (_) {
        // Ignore corrupt cache entries so one bad record doesn't block reminders.
      }
    }
    return events;
  }

  Future<void> _prunePendingReminderRequests({
    required Set<int> activeReminderIds,
  }) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (_isManagedReminderId(request.id) &&
          !activeReminderIds.contains(request.id)) {
        await _plugin.cancel(request.id);
      }
    }
  }

  List<_ScheduledReminder> _buildTaskReminders(TaskModel task) {
    if (task.isComplete) return const [];

    final now = DateTime.now();
    final reminders = <_ScheduledReminder>[];
    final reminderAt = task.reminderAt;
    final deadline = task.deadline;

    if (reminderAt != null &&
        reminderAt.isAfter(now) &&
        !_isSameMoment(reminderAt, deadline) &&
        (deadline == null || reminderAt.isBefore(deadline))) {
      reminders.add(
        _ScheduledReminder(
          id: _taskIncomingReminderId(task.id),
          title: 'Task coming up',
          body: task.title,
          scheduledAt: reminderAt,
          details: _incomingNotificationDetails,
        ),
      );
    }

    if (deadline != null && deadline.isAfter(now)) {
      reminders.add(
        _ScheduledReminder(
          id: _taskDeadlineReminderId(task.id),
          title: 'Task deadline',
          body: task.title,
          scheduledAt: deadline,
          details: _alarmNotificationDetails,
        ),
      );
    }

    if (deadline == null &&
        reminderAt != null &&
        reminderAt.isAfter(now) &&
        reminders.isEmpty) {
      reminders.add(
        _ScheduledReminder(
          id: _taskIncomingReminderId(task.id),
          title: 'Task reminder',
          body: task.title,
          scheduledAt: reminderAt,
          details: _incomingNotificationDetails,
        ),
      );
    }

    return reminders;
  }

  List<_ScheduledReminder> _buildEventReminders(EventModel event) {
    if (event.repeat == EventRepeat.none) {
      return _buildEventOccurrenceReminders(
        event: event,
        incomingId: _eventIncomingReminderId(event.id),
        startId: _eventStartReminderId(event.id),
      );
    }

    final occurrences = _resolveRecurringEventOccurrences(event);
    return [
      for (var index = 0; index < occurrences.length; index++)
        ..._buildEventOccurrenceReminders(
          event: occurrences[index],
          incomingId: _eventRecurringIncomingReminderId(event.id, index),
          startId: _eventRecurringStartReminderId(event.id, index),
        ),
    ];
  }

  List<_ScheduledReminder> _buildEventOccurrenceReminders({
    required EventModel event,
    required int incomingId,
    required int startId,
  }) {
    final now = DateTime.now();
    final reminders = <_ScheduledReminder>[];
    final reminderAt = event.reminderAt;

    if (reminderAt != null &&
        reminderAt.isAfter(now) &&
        reminderAt.isBefore(event.startTime)) {
      reminders.add(
        _ScheduledReminder(
          id: incomingId,
          title: 'Event coming up',
          body: event.title,
          scheduledAt: reminderAt,
          details: _incomingNotificationDetails,
        ),
      );
    }

    if (event.startTime.isAfter(now)) {
      reminders.add(
        _ScheduledReminder(
          id: startId,
          title: 'Event starting now',
          body: event.title,
          scheduledAt: event.startTime,
          details: _alarmNotificationDetails,
        ),
      );
    }

    return reminders;
  }

  List<EventModel> _resolveRecurringEventOccurrences(EventModel event) {
    final now = DateTime.now();
    final searchStart = _dateOnly(
      event.startTime.isAfter(now) ? event.startTime : now,
    );
    final horizonEnd = _dateOnly(now.add(_eventSchedulingHorizon));
    final recurrenceEnd =
        event.recurrenceEnd == null ? null : _dateOnly(event.recurrenceEnd!);
    final searchEnd = recurrenceEnd == null || recurrenceEnd.isAfter(horizonEnd)
        ? horizonEnd
        : recurrenceEnd;
    final occurrences = <EventModel>[];

    for (var day = searchStart;
        !day.isAfter(searchEnd) && occurrences.length < _recurringSlotCount;
        day = day.add(const Duration(days: 1))) {
      if (!_occursOnDay(event, day)) continue;

      final occurrence = _buildOccurrence(event, day);
      if (occurrence.startTime.isAfter(now) ||
          (occurrence.reminderAt?.isAfter(now) ?? false)) {
        occurrences.add(occurrence);
      }
    }

    return occurrences;
  }

  EventModel _buildOccurrence(EventModel event, DateTime day) {
    if (event.repeat == EventRepeat.none) return event;

    final duration = event.endTime.difference(event.startTime);
    final reminderLead = event.reminderAt == null
        ? null
        : event.startTime.difference(event.reminderAt!);
    final occurrenceStart = DateTime(
      day.year,
      day.month,
      day.day,
      event.startTime.hour,
      event.startTime.minute,
      event.startTime.second,
      event.startTime.millisecond,
      event.startTime.microsecond,
    );

    return event.copyWith(
      startTime: occurrenceStart,
      endTime: occurrenceStart.add(duration),
      reminderAt:
          reminderLead == null ? null : occurrenceStart.subtract(reminderLead),
    );
  }

  bool _isSameMoment(DateTime left, DateTime? right) {
    return right != null && left.isAtSameMomentAs(right);
  }

  bool _occursOnDay(EventModel event, DateTime day) {
    final target = _dateOnly(day);
    final startDay = _dateOnly(event.startTime);

    if (target.isBefore(startDay)) return false;

    if (event.recurrenceEnd != null &&
        target.isAfter(_dateOnly(event.recurrenceEnd!))) {
      return false;
    }

    for (final skip in event.skippedOccurrences) {
      final skipDay = DateTime.tryParse(skip);
      if (skipDay != null && _isSameDay(skipDay, target)) {
        return false;
      }
    }

    if (event.repeat == EventRepeat.none) {
      return _isSameDay(startDay, target);
    }

    final daysDiff = target.difference(startDay).inDays;

    return switch (event.repeat) {
      EventRepeat.none => false,
      EventRepeat.daily => daysDiff % event.repeatInterval == 0,
      EventRepeat.weekly => () {
          if (event.repeatWeekdays.isNotEmpty &&
              !event.repeatWeekdays.contains(target.weekday)) {
            return false;
          }
          final weekStart =
              startDay.subtract(Duration(days: startDay.weekday - 1));
          final targetWeekStart =
              target.subtract(Duration(days: target.weekday - 1));
          final weeksDiff = targetWeekStart.difference(weekStart).inDays ~/ 7;
          return weeksDiff % event.repeatInterval == 0;
        }(),
      EventRepeat.monthly => () {
          final monthsDiff = (target.year - startDay.year) * 12 +
              target.month -
              startDay.month;
          if (monthsDiff % event.repeatInterval != 0) return false;
          return target.day == startDay.day;
        }(),
    };
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  int _taskIncomingReminderId(int taskId) =>
      _scopedNotificationId(_taskIncomingBase, 'task-incoming', taskId);

  int _taskDeadlineReminderId(int taskId) =>
      _scopedNotificationId(_taskDeadlineBase, 'task-deadline', taskId);

  int _eventIncomingReminderId(int eventId) =>
      _scopedNotificationId(_eventIncomingBase, 'event-incoming', eventId);

  int _eventStartReminderId(int eventId) =>
      _scopedNotificationId(_eventStartBase, 'event-start', eventId);

  int _eventRecurringIncomingReminderId(int eventId, int slot) =>
      _scopedNotificationId(
        _eventRecurringIncomingBase,
        'event-recurring-incoming',
        eventId,
        slot,
      );

  int _eventRecurringStartReminderId(int eventId, int slot) =>
      _scopedNotificationId(
        _eventRecurringStartBase,
        'event-recurring-start',
        eventId,
        slot,
      );

  int _standaloneReminderId(int reminderId) =>
      _scopedNotificationId(_standaloneReminderBase, 'reminder', reminderId);

  int _standaloneRecurringReminderId(int reminderId, int slot) =>
      _scopedNotificationId(
        _standaloneRecurringReminderBase,
        'reminder-recurring',
        reminderId,
        slot,
      );

  int _scopedNotificationId(
    int base,
    String scope,
    int sourceId, [
    int slot = 0,
  ]) {
    final hash = _stableHash('$scope:$sourceId:$slot');
    return base + (hash % _notificationRangeSize);
  }

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & _maxAndroidNotificationId;
  }

  int? _legacyTaskReminderId(int taskId) =>
      _legacyNotificationId(100000 + taskId);

  int? _legacyEventReminderId(int eventId) =>
      _legacyNotificationId(200000 + eventId);

  int? _legacyStandaloneReminderId(int reminderId) =>
      _legacyNotificationId(300000 + reminderId);

  int? _legacyEventRecurringReminderId(int eventId, int slot) =>
      _legacyNotificationId(10000000 + (eventId * _recurringSlotCount) + slot);

  int? _legacyNotificationId(int id) => _isValidNotificationId(id) ? id : null;

  bool _isValidNotificationId(int? id) {
    return id != null && id > 0 && id <= _maxAndroidNotificationId;
  }

  Future<void> _cancelReminderIds(Iterable<int?> ids) async {
    final uniqueIds = <int>{};
    for (final id in ids) {
      if (_isValidNotificationId(id) && uniqueIds.add(id!)) {
        await _plugin.cancel(id);
      }
    }
  }

  bool _isManagedReminderId(int id) {
    if (id >= 100000 && id < 400000) return true;
    if (id >= 10000000 && id < 100000000) return true;

    return _isInNotificationRange(id, _taskIncomingBase) ||
        _isInNotificationRange(id, _taskDeadlineBase) ||
        _isInNotificationRange(id, _eventIncomingBase) ||
        _isInNotificationRange(id, _eventStartBase) ||
        _isInNotificationRange(id, _eventRecurringIncomingBase) ||
        _isInNotificationRange(id, _eventRecurringStartBase) ||
        _isInNotificationRange(id, _standaloneReminderBase) ||
        _isInNotificationRange(id, _standaloneRecurringReminderBase);
  }

  bool _isInNotificationRange(int id, int base) {
    return id >= base && id < base + _notificationRangeSize;
  }

  List<_ScheduledReminder> _buildStandaloneReminders(ReminderModel reminder) {
    if (reminder.isCompleted) return const [];

    final reminderTimes = _resolveStandaloneReminderTimes(reminder);
    if (reminderTimes.isEmpty) return const [];

    return [
      for (var index = 0; index < reminderTimes.length; index++)
        _ScheduledReminder(
          id: reminder.repeat == ReminderRepeat.none
              ? _standaloneReminderId(reminder.id)
              : _standaloneRecurringReminderId(reminder.id, index),
          title: 'Reminder',
          body: reminder.title,
          scheduledAt: reminderTimes[index],
          details: _alarmNotificationDetails,
        ),
    ];
  }

  List<DateTime> _resolveStandaloneReminderTimes(ReminderModel reminder) {
    if (reminder.isCompleted) return const [];

    final now = DateTime.now();
    if (reminder.repeat == ReminderRepeat.none) {
      return reminder.reminderTime.isAfter(now)
          ? [reminder.reminderTime]
          : const [];
    }

    var candidate = reminder.reminderTime;
    var guard = 0;
    while (!candidate.isAfter(now) && guard < 10000) {
      candidate = _nextStandaloneReminderTime(candidate, reminder.repeat);
      guard++;
    }
    if (!candidate.isAfter(now)) return const [];

    final times = <DateTime>[];
    while (times.length < _recurringSlotCount) {
      times.add(candidate);
      candidate = _nextStandaloneReminderTime(candidate, reminder.repeat);
    }
    return times;
  }

  DateTime _nextStandaloneReminderTime(
    DateTime value,
    ReminderRepeat repeat,
  ) {
    return switch (repeat) {
      ReminderRepeat.none => value,
      ReminderRepeat.daily => value.add(const Duration(days: 1)),
      ReminderRepeat.weekly => value.add(const Duration(days: 7)),
      ReminderRepeat.monthly => _addMonthsPreservingTime(value, 1),
    };
  }

  DateTime _addMonthsPreservingTime(DateTime value, int months) {
    final monthIndex = value.month - 1 + months;
    final year = value.year + (monthIndex ~/ 12);
    final month = (monthIndex % 12) + 1;
    final maxDay = _daysInMonth(year, month);
    final day = value.day > maxDay ? maxDay : value.day;

    return DateTime(
      year,
      month,
      day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  Future<List<ReminderModel>> _readCachedReminders(
    LocalCacheService cache,
    CacheSession session,
  ) async {
    final raw = await cache.readJsonListForUser(
      session,
      CacheKeys.reminders(session.uid),
    );
    final reminders = <ReminderModel>[];
    for (final item in raw) {
      try {
        reminders.add(ReminderModel.fromJson(item));
      } catch (_) {
        // Ignore corrupt cache entries.
      }
    }
    return reminders;
  }

  String _focusTaskLabel(String? taskTitle) {
    final trimmed = taskTitle?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Your focus session';
    }
    return trimmed;
  }
}

class NotificationSchedulingException implements Exception {
  const NotificationSchedulingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ScheduledReminder {
  const _ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.details,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final NotificationDetails details;
}
