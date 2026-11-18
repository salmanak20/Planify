import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/services/notifications_service.dart';
import 'package:planify_app/core/utils/app_snackbar.dart';
import 'package:planify_app/data/models/event_model.dart';
import 'package:planify_app/data/repositories/events_repository.dart';

class EventsNotifier extends StateNotifier<AsyncValue<List<EventModel>>> {
  final EventsRepository _repo;
  final NotificationsService _notifications;

  EventsNotifier(this._repo, this._notifications)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({DateTime? start, DateTime? end}) async {
    state = const AsyncValue.loading();
    state =
        await AsyncValue.guard(() => _repo.getEvents(start: start, end: end));
    final events = state.valueOrNull;
    if (events != null) {
      await _trySyncEvents(events);
    }
  }

  Future<void> create({
    required String title,
    String? description,
    String? location,
    String color = '#435f92',
    int? projectId,
    required DateTime startTime,
    required DateTime endTime,
    DateTime? reminderAt,
    bool allDay = false,
    EventRepeat repeat = EventRepeat.none,
    int repeatInterval = 1,
    List<int> repeatWeekdays = const [],
    DateTime? recurrenceEnd,
    List<String> skippedOccurrences = const [],
  }) async {
    final now = DateTime.now();
    final tempId = -now.microsecondsSinceEpoch;
    final optimistic = EventModel(
      id: tempId,
      userId: 0,
      projectId: projectId,
      title: title,
      description: description,
      location: location,
      color: color,
      startTime: startTime,
      endTime: endTime,
      reminderAt: reminderAt,
      allDay: allDay,
      repeat: repeat,
      repeatInterval: repeatInterval,
      repeatWeekdays: repeatWeekdays,
      recurrenceEnd: recurrenceEnd,
      skippedOccurrences: skippedOccurrences,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.valueOrNull ?? [];
    final optimisticList = [
      ...current.where((item) => item.id != optimistic.id),
      optimistic,
    ]..sort((a, b) => a.startTime.compareTo(b.startTime));
    state = AsyncValue.data(optimisticList);

    try {
      final event = await _repo.createEvent(
        title: title,
        description: description,
        location: location,
        color: color,
        projectId: projectId,
        startTime: startTime,
        endTime: endTime,
        reminderAt: reminderAt,
        allDay: allDay,
        repeat: repeat,
        repeatInterval: repeatInterval,
        repeatWeekdays: repeatWeekdays,
        recurrenceEnd: recurrenceEnd,
        skippedOccurrences: skippedOccurrences,
      );
      final latest = state.valueOrNull ?? [];
      final newList = [
        ...latest.where(
          (item) => item.id != tempId && item.id != event.id,
        ),
        event,
      ]..sort((a, b) => a.startTime.compareTo(b.startTime));
      state = AsyncValue.data(newList);
      await _trySyncEvent(event);
    } catch (_) {
      final latest = state.valueOrNull ?? [];
      state = AsyncValue.data(
        latest.where((item) => item.id != tempId).toList(),
      );
      rethrow;
    }
  }

  Future<void> update(int id, Map<String, dynamic> updates) async {
    final current = state.valueOrNull ?? [];
    final original = _findById(current, id);

    if (original == null) {
      final updated = await _repo.updateEvent(
        id,
        Map<String, dynamic>.from(updates),
      );
      await _trySyncEvent(updated);
      return;
    }

    final optimistic = _applyUpdates(original, updates);
    final optimisticList = [
      for (final event in current)
        if (event.id == id) optimistic else event,
    ]..sort((a, b) => a.startTime.compareTo(b.startTime));
    state = AsyncValue.data(optimisticList);

    try {
      final updated = await _repo.updateEvent(
        id,
        Map<String, dynamic>.from(updates),
      );
      final latest = state.valueOrNull ?? [];
      final newList = [
        for (final event in latest)
          if (event.id == id) updated else event,
      ]..sort((a, b) => a.startTime.compareTo(b.startTime));
      state = AsyncValue.data(newList);
      await _trySyncEvent(updated);
    } catch (_) {
      state = AsyncValue.data(current);
      await _trySyncEvent(original);
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    final current = state.valueOrNull ?? [];
    final original = _findById(current, id);
    state = AsyncValue.data(current.where((event) => event.id != id).toList());

    try {
      await _repo.deleteEvent(id);
    } catch (_) {
      state = AsyncValue.data(current);
      if (original != null) {
        await _trySyncEvent(original);
      }
      rethrow;
    }
    await _tryCancelEventReminder(id);
  }

  EventModel? _findById(List<EventModel> events, int id) {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  EventModel _applyUpdates(EventModel event, Map<String, dynamic> updates) {
    final data = Map<String, dynamic>.from(event.toJson())
      ..addAll(updates)
      ..['updated_at'] = DateTime.now().toIso8601String();
    return EventModel.fromJson(data);
  }

  List<EventModel> eventsForDay(DateTime day) {
    final events = state.valueOrNull ?? const <EventModel>[];
    return [
      for (final event in events)
        if (_occursOnDay(event, day)) _buildOccurrence(event, day),
    ]..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<EventModel> get upcomingEvents {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    final upcoming = <EventModel>[];
    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      for (final event in eventsForDay(day)) {
        if (event.startTime.isAfter(now) && event.startTime.isBefore(end)) {
          upcoming.add(event);
        }
      }
    }
    upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.take(3).toList();
  }

  bool _occursOnDay(EventModel event, DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    final startDay = DateTime(
      event.startTime.year,
      event.startTime.month,
      event.startTime.day,
    );

    if (target.isBefore(startDay)) return false;

    if (event.recurrenceEnd != null) {
      if (target.isAfter(event.recurrenceEnd!)) return false;
    }

    if (event.skippedOccurrences.isNotEmpty) {
      for (final skip in event.skippedOccurrences) {
        final skipDay = DateTime.tryParse(skip);
        if (skipDay != null && _isSameDay(skipDay, target)) {
          return false;
        }
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
          final offsetStart =
              startDay.subtract(Duration(days: startDay.weekday - 1));
          final offsetTarget =
              target.subtract(Duration(days: target.weekday - 1));
          final weeksDiff = offsetTarget.difference(offsetStart).inDays ~/ 7;
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

  EventModel _buildOccurrence(EventModel event, DateTime day) {
    if (event.repeat == EventRepeat.none) return event;

    final duration = event.endTime.difference(event.startTime);
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
      reminderAt: event.reminderAt == null
          ? null
          : occurrenceStart.subtract(
              event.startTime.difference(event.reminderAt!),
            ),
    );
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _trySyncEvent(EventModel event) async {
    try {
      await _notifications.syncEvent(event);
    } catch (error) {
      // The event was saved; notification scheduling is best-effort.
      _showNotificationFailure(error);
    }
  }

  Future<void> _trySyncEvents(List<EventModel> events) async {
    try {
      await _notifications.syncEvents(events);
    } catch (error) {
      _showNotificationFailure(error);
    }
  }

  Future<void> _tryCancelEventReminder(int id) async {
    try {
      await _notifications.cancelEventReminder(id);
    } catch (_) {
      // The event was deleted; stale local reminder cleanup should not roll it back.
    }
  }

  void _showNotificationFailure(Object error) {
    debugPrint('Event notification scheduling failed: $error');
    final message = error is NotificationSchedulingException
        ? error.message
        : 'Event saved, but local notification scheduling failed.';
    showPlanifySnackBar(message);
  }
}

final eventsProvider =
    StateNotifierProvider<EventsNotifier, AsyncValue<List<EventModel>>>(
  (ref) => EventsNotifier(
    ref.watch(eventsRepositoryProvider),
    NotificationsService.instance,
  ),
);
