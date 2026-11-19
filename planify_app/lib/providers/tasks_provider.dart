import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/services/notifications_service.dart';
import 'package:planify_app/core/services/audio_service.dart';
import 'package:planify_app/core/utils/app_snackbar.dart';
import 'package:planify_app/data/models/task_model.dart';
import 'package:planify_app/data/repositories/tasks_repository.dart';
import 'package:planify_app/providers/account_scope_provider.dart';
import 'package:planify_app/providers/account_scoped_notifier.dart';

class TasksNotifier
    extends AccountScopedStateNotifier<AsyncValue<List<TaskModel>>> {
  final TasksRepository _repo;
  final NotificationsService _notifications;
  final String? _accountUid;

  TasksNotifier(this._repo, this._notifications, this._accountUid)
      : super(_accountUid == null
            ? const AsyncValue.data([])
            : const AsyncValue.loading()) {
    if (_accountUid != null) load();
  }

  Future<void> load({
    TaskPriority? priority,
    int? projectId,
    bool? isComplete,
  }) async {
    if (_accountUid == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => _repo.getTasks(
        priority: priority,
        projectId: projectId,
        isComplete: isComplete,
      ),
    );
    if (!mounted) return;
    state = result;
    final tasks = state.valueOrNull;
    if (mounted && tasks != null) {
      await _trySyncTasks(tasks);
    }
  }

  Future<void> create({
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    List<String> tags = const [],
    DateTime? deadline,
    DateTime? reminderAt,
    int? projectId,
    int? parentTaskId,
    int? sourceNoteId,
    String? sourceNoteLine,
  }) async {
    final now = DateTime.now();
    final tempId = now.millisecondsSinceEpoch;

    // 1. Optimistic Update
    final tempTask = TaskModel(
      id: tempId,
      userId: 0,
      projectId: projectId,
      title: title,
      description: description,
      priority: priority,
      isComplete: false,
      tags: tags,
      deadline: deadline,
      reminderAt: reminderAt,
      subtasks: const [],
      createdAt: now,
      updatedAt: now,
      parentTaskId: parentTaskId,
      sourceNoteId: sourceNoteId,
      sourceNoteLine: sourceNoteLine,
    );

    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([tempTask, ...current]);

    try {
      // 2. Background Sync
      final task = await _repo.createTask(
        title: title,
        description: description,
        priority: priority,
        tags: tags,
        deadline: deadline,
        reminderAt: reminderAt,
        projectId: projectId,
        parentTaskId: parentTaskId,
        sourceNoteId: sourceNoteId,
        sourceNoteLine: sourceNoteLine,
      );

      // 3. Replace temp task with real task
      final updatedList = state.valueOrNull ?? [];
      state = AsyncValue.data([
        task,
        ...updatedList.where((item) => item.id != tempId && item.id != task.id)
      ]);
      await _trySyncTask(task);
    } catch (e) {
      // 4. Rollback
      final rollbackList = state.valueOrNull ?? [];
      state = AsyncValue.data(
          rollbackList.where((item) => item.id != tempId).toList());
      rethrow;
    }
  }

  Future<void> update(int id, Map<String, dynamic> updates) async {
    final current = state.valueOrNull ?? [];
    final index = current.indexWhere((task) => task.id == id);

    if (index == -1) {
      final updated =
          await _repo.updateTask(id, Map<String, dynamic>.from(updates));
      await _trySyncTask(updated);
      return;
    }

    final original = current[index];
    final optimistic = _applyUpdates(original, updates);
    state = AsyncValue.data([
      for (final task in current)
        if (task.id == id) optimistic else task,
    ]);

    try {
      final updated = await _repo.updateTask(
        id,
        Map<String, dynamic>.from(updates),
      );
      final latest = state.valueOrNull ?? [];
      state = AsyncValue.data([
        for (final task in latest)
          if (task.id == id) updated else task,
      ]);
      await _trySyncTask(updated);
    } catch (_) {
      state = AsyncValue.data(current);
      await _trySyncTask(original);
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((task) => task.id != id).toList());

    try {
      await _repo.deleteTask(id);
    } catch (_) {
      state = AsyncValue.data(current);
      final restored = _findById(current, id);
      if (restored != null) {
        await _trySyncTask(restored);
      }
      rethrow;
    }
    await _tryCancelTaskReminder(id);
  }

  Future<void> archive(int id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((task) => task.id != id).toList());

    try {
      await _repo.archiveTask(id);
    } catch (_) {
      state = AsyncValue.data(current);
      final restored = _findById(current, id);
      if (restored != null) {
        await _trySyncTask(restored);
      }
      rethrow;
    }
    await _tryCancelTaskReminder(id);
  }

  Future<void> toggleComplete(int id) async {
    final current = state.valueOrNull ?? [];
    final taskIndex = current.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;

    final originalTask = current[taskIndex];
    final optimisticTask =
        originalTask.copyWith(isComplete: !originalTask.isComplete);

    if (optimisticTask.isComplete) {
      audioService.playTaskComplete();
    }

    // 1. Optimistic Update
    state = AsyncValue.data([
      for (final task in current)
        if (task.id == id) optimisticTask else task,
    ]);

    try {
      // 2. Background Sync
      final updated = await _repo.toggleComplete(id);
      final latest = state.valueOrNull ?? [];
      state = AsyncValue.data([
        for (final task in latest)
          if (task.id == id) updated else task,
      ]);
      await _trySyncTask(updated);
    } catch (e) {
      // 3. Rollback
      final rollbackList = state.valueOrNull ?? [];
      state = AsyncValue.data([
        for (final task in rollbackList)
          if (task.id == id) originalTask else task,
      ]);
      rethrow;
    }
  }

  Future<void> patchSubtasks(int id, List<SubtaskModel> subtasks) async {
    final current = state.valueOrNull ?? [];
    final original = _findById(current, id);
    if (original != null) {
      state = AsyncValue.data([
        for (final task in current)
          if (task.id == id)
            task.copyWith(subtasks: subtasks, updatedAt: DateTime.now())
          else
            task,
      ]);
    }

    try {
      final updated = await _repo.patchSubtasks(
        id,
        subtasks
            .map((subtask) => {
                  'id': subtask.id,
                  'title': subtask.title,
                  'is_complete': subtask.isComplete,
                })
            .toList(),
      );
      final latest = state.valueOrNull ?? [];
      state = AsyncValue.data([
        for (final task in latest)
          if (task.id == id) updated else task,
      ]);
    } catch (_) {
      if (original != null) {
        state = AsyncValue.data(current);
      }
      rethrow;
    }
  }

  TaskModel _applyUpdates(TaskModel task, Map<String, dynamic> updates) {
    final data = Map<String, dynamic>.from(task.toJson())
      ..addAll(updates)
      ..['updated_at'] = DateTime.now().toIso8601String();
    return TaskModel.fromJson(data);
  }

  TaskModel? _findById(List<TaskModel> tasks, int id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<void> createFromCalendarDay({
    required String title,
    required DateTime day,
    int? projectId,
    String? description,
  }) async {
    final now = DateTime.now();
    final tempId = now.millisecondsSinceEpoch;

    // 1. Optimistic Update
    final tempTask = TaskModel(
      id: tempId,
      userId: 0,
      projectId: projectId,
      title: title,
      description: description,
      priority: TaskPriority.medium,
      isComplete: false,
      tags: const [],
      subtasks: const [],
      deadline: DateTime(day.year, day.month, day.day),
      createdAt: now,
      updatedAt: now,
    );

    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([tempTask, ...current]);

    try {
      // 2. Background Sync
      final task = await _repo.createFromCalendarDay(
        title: title,
        day: day,
        projectId: projectId,
        description: description,
      );

      // 3. Replace temp task with real task
      final updatedList = state.valueOrNull ?? [];
      state = AsyncValue.data([
        task,
        ...updatedList.where((item) => item.id != tempId && item.id != task.id)
      ]);
      await _trySyncTask(task);
    } catch (e) {
      // 4. Rollback
      final rollbackList = state.valueOrNull ?? [];
      state = AsyncValue.data(
          rollbackList.where((item) => item.id != tempId).toList());
      rethrow;
    }
  }

  List<TaskModel> get todayTasks {
    final now = DateTime.now();
    return state.valueOrNull
            ?.where((t) =>
                !t.isComplete &&
                t.deadline != null &&
                t.deadline!.day == now.day &&
                t.deadline!.month == now.month &&
                t.deadline!.year == now.year)
            .take(5)
            .toList() ??
        [];
  }

  int get completedThisWeek {
    final weekStart =
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    return state.valueOrNull
            ?.where((t) => t.isComplete && t.updatedAt.isAfter(weekStart))
            .length ??
        0;
  }

  int get totalThisWeek {
    final weekStart =
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    return state.valueOrNull
            ?.where((t) => t.createdAt.isAfter(weekStart))
            .length ??
        0;
  }

  Future<void> _trySyncTask(TaskModel task) async {
    final uid = _accountUid;
    if (uid == null) return;
    try {
      await _notifications.syncTask(task, accountUid: uid);
    } catch (error) {
      // Saving the task succeeded; notification scheduling should not roll it back.
      _showNotificationFailure(error);
    }
  }

  Future<void> _trySyncTasks(List<TaskModel> tasks) async {
    final uid = _accountUid;
    if (uid == null) return;
    try {
      await _notifications.syncTasks(tasks, accountUid: uid);
    } catch (error) {
      _showNotificationFailure(error);
    }
  }

  Future<void> _tryCancelTaskReminder(int id) async {
    final uid = _accountUid;
    if (uid == null) return;
    try {
      await _notifications.cancelTaskReminder(id, accountUid: uid);
    } catch (_) {
      // Deleting/archiving succeeded even if local reminder cleanup fails.
    }
  }

  void _showNotificationFailure(Object error) {
    debugPrint('Task notification scheduling failed: $error');
    final message = error is NotificationSchedulingException
        ? error.message
        : 'Task saved, but local notification scheduling failed.';
    showPlanifySnackBar(message);
  }
}

final tasksProvider =
    StateNotifierProvider<TasksNotifier, AsyncValue<List<TaskModel>>>(
  (ref) {
    final uid = ref.watch(activeAccountUidProvider);
    return TasksNotifier(
      ref.watch(tasksRepositoryProvider),
      NotificationsService.instance,
      uid,
    );
  },
);
