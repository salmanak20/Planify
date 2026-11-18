import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/services/notifications_service.dart';
import 'package:planify_app/core/services/audio_service.dart';
import 'package:planify_app/core/utils/app_snackbar.dart';
import 'package:planify_app/data/models/reminder_model.dart';
import 'package:planify_app/data/repositories/reminders_repository.dart';
import 'package:planify_app/providers/account_scope_provider.dart';
import 'package:planify_app/providers/account_scoped_notifier.dart';

class RemindersNotifier
    extends AccountScopedStateNotifier<AsyncValue<List<ReminderModel>>> {
  final RemindersRepository _repo;
  final NotificationsService _notifications;
  final String? _accountUid;

  RemindersNotifier(this._repo, this._notifications, this._accountUid)
      : super(_accountUid == null
            ? const AsyncValue.data([])
            : const AsyncValue.loading()) {
    if (_accountUid != null) load();
  }

  Future<void> load({bool? isCompleted}) async {
    if (_accountUid == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => _repo.getReminders(isCompleted: isCompleted),
    );
    if (!mounted) return;
    state = result;
    final reminders = state.valueOrNull;
    if (mounted && reminders != null) {
      await _trySyncReminders(reminders);
    }
  }

  Future<void> create({
    required String title,
    String? notes,
    required DateTime reminderTime,
    ReminderRepeat repeat = ReminderRepeat.none,
  }) async {
    final now = DateTime.now();
    final tempId = -now.microsecondsSinceEpoch;
    final optimistic = ReminderModel(
      id: tempId,
      userId: 0,
      title: title,
      notes: notes,
      reminderTime: reminderTime,
      isCompleted: false,
      repeat: repeat,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.valueOrNull ?? [];
    final optimisticList = [
      ...current.where((r) => r.id != optimistic.id),
      optimistic,
    ]..sort((a, b) => a.reminderTime.compareTo(b.reminderTime));
    state = AsyncValue.data(optimisticList);

    try {
      final reminder = await _repo.createReminder(
        title: title,
        notes: notes,
        reminderTime: reminderTime,
        repeat: repeat,
      );
      final latest = state.valueOrNull ?? [];
      final newList = [
        ...latest.where(
          (r) => r.id != tempId && r.id != reminder.id,
        ),
        reminder,
      ]..sort((a, b) => a.reminderTime.compareTo(b.reminderTime));
      state = AsyncValue.data(newList);
      await _trySyncReminder(reminder);
    } catch (_) {
      final latest = state.valueOrNull ?? [];
      state = AsyncValue.data(
        latest.where((r) => r.id != tempId).toList(),
      );
      rethrow;
    }
  }

  Future<void> update(int id, Map<String, dynamic> updates) async {
    final current = state.valueOrNull ?? [];
    final original = _findById(current, id);

    if (original == null) {
      final updated = await _repo.updateReminder(
        id,
        Map<String, dynamic>.from(updates),
      );
      await _trySyncReminder(updated);
      return;
    }

    final optimistic = _applyUpdates(original, updates);
    state = AsyncValue.data([
      for (final r in current)
        if (r.id == id) optimistic else r,
    ]);

    try {
      final updated = await _repo.updateReminder(
        id,
        Map<String, dynamic>.from(updates),
      );
      final latest = state.valueOrNull ?? [];
      state = AsyncValue.data([
        for (final r in latest)
          if (r.id == id) updated else r,
      ]);
      await _trySyncReminder(updated);
    } catch (_) {
      state = AsyncValue.data(current);
      await _trySyncReminder(original);
      rethrow;
    }
  }

  Future<void> toggleComplete(int id) async {
    final updated = await _repo.toggleComplete(id);
    if (updated.isCompleted) {
      audioService.playTaskComplete();
    }
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([
      for (final r in current)
        if (r.id == id) updated else r,
    ]);
    await _trySyncReminder(updated);
  }

  Future<void> delete(int id) async {
    final current = state.valueOrNull ?? [];
    final original = _findById(current, id);
    state = AsyncValue.data(current.where((r) => r.id != id).toList());

    try {
      await _repo.deleteReminder(id);
    } catch (_) {
      state = AsyncValue.data(current);
      if (original != null) {
        await _trySyncReminder(original);
      }
      rethrow;
    }
    await _tryCancelReminder(id);
  }

  ReminderModel? _findById(List<ReminderModel> reminders, int id) {
    for (final reminder in reminders) {
      if (reminder.id == id) return reminder;
    }
    return null;
  }

  ReminderModel _applyUpdates(
    ReminderModel reminder,
    Map<String, dynamic> updates,
  ) {
    final data = Map<String, dynamic>.from(reminder.toJson())
      ..addAll(updates)
      ..['updated_at'] = DateTime.now().toIso8601String();
    return ReminderModel.fromJson(data);
  }

  /// Upcoming non-completed reminders (for dashboard).
  List<ReminderModel> get upcomingReminders {
    final now = DateTime.now();
    return (state.valueOrNull ?? [])
        .where((r) => !r.isCompleted && r.reminderTime.isAfter(now))
        .take(4)
        .toList();
  }

  /// Today's reminders.
  List<ReminderModel> get todayReminders {
    final now = DateTime.now();
    return (state.valueOrNull ?? [])
        .where((r) =>
            r.reminderTime.year == now.year &&
            r.reminderTime.month == now.month &&
            r.reminderTime.day == now.day)
        .toList();
  }

  Future<void> _trySyncReminder(ReminderModel reminder) async {
    try {
      await _notifications.syncReminder(reminder);
    } catch (error) {
      _showNotificationFailure(error);
    }
  }

  Future<void> _tryCancelReminder(int id) async {
    try {
      await _notifications.cancelReminder(id);
    } catch (_) {
      // Deleting succeeded even if local reminder cleanup fails.
    }
  }

  Future<void> _trySyncReminders(List<ReminderModel> reminders) async {
    try {
      await _notifications.syncReminders(reminders);
    } catch (error) {
      _showNotificationFailure(error);
    }
  }

  void _showNotificationFailure(Object error) {
    debugPrint('Reminder notification scheduling failed: $error');
    final message = error is NotificationSchedulingException
        ? error.message
        : 'Reminder saved, but local notification scheduling failed.';
    showPlanifySnackBar(message);
  }
}

final remindersProvider =
    StateNotifierProvider<RemindersNotifier, AsyncValue<List<ReminderModel>>>(
  (ref) => RemindersNotifier(
    ref.watch(remindersRepositoryProvider),
    NotificationsService.instance,
    ref.watch(activeAccountUidProvider),
  ),
);
