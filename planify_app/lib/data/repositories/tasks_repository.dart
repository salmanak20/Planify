import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/constants/app_flags.dart';
import 'package:planify_app/core/utils/firebase_identity.dart';
import 'package:planify_app/data/datasources/cache_keys.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/data/mock/demo_data.dart';
import 'package:planify_app/data/models/task_model.dart';
import 'package:planify_app/providers/account_scope_provider.dart';

class TasksRepository {
  final LocalCacheService _cache;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _uid;
  final CacheSession? _session;

  TasksRepository(this._cache, this._uid)
      : _session = _uid == null ? null : _cache.captureSession(_uid);

  int get _userId => currentStableUserId(_auth) ?? 0;

  Future<List<TaskModel>> getTasks({
    TaskPriority? priority,
    int? projectId,
    bool? isComplete,
  }) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      return _applyFilters(
        cached,
        priority: priority,
        projectId: projectId,
        isComplete: isComplete,
      );
    }
    try {
      Query<Map<String, dynamic>> query = ownedQuery(_firestore, 'tasks', _uid);

      final snapshot = await query.get();
      var tasks =
          snapshot.docs.map((doc) => TaskModel.fromJson(doc.data())).toList();

      if (priority != null) {
        tasks = tasks.where((t) => t.priority == priority).toList();
      }
      if (projectId != null) {
        tasks = tasks.where((t) => t.projectId == projectId).toList();
      }
      if (isComplete != null) {
        tasks = tasks.where((t) => t.isComplete == isComplete).toList();
      }

      if (priority == null && projectId == null && isComplete == null) {
        await _writeCache(tasks);
      }
      return tasks;
    } catch (_) {
      final cached = await _readCache();
      if (cached.isNotEmpty) {
        return _applyFilters(
          cached,
          priority: priority,
          projectId: projectId,
          isComplete: isComplete,
        );
      }
      rethrow;
    }
  }

  Future<TaskModel> createTask({
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
    final id = now.millisecondsSinceEpoch;

    final task = TaskModel(
      id: id,
      userId: _userId == 0 ? demoUser.id : _userId,
      projectId: projectId,
      eventId: null,
      parentTaskId: parentTaskId,
      title: title,
      description: description,
      priority: priority,
      isComplete: false,
      tags: tags,
      deadline: deadline,
      reminderAt: reminderAt,
      subtasks: const [],
      sourceNoteId: sourceNoteId,
      sourceNoteLine: sourceNoteLine,
      createdAt: now,
      updatedAt: now,
    );

    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache([task, ...cached]);
      return task;
    }

    await _firestore
        .collection('tasks')
        .doc(id.toString())
        .set(withFirebaseOwner(task.toJson(), _uid));

    final cached = await _readCache();
    await _writeCache([task, ...cached.where((item) => item.id != task.id)]);
    return task;
  }

  Future<TaskModel> updateTask(int id, Map<String, dynamic> updates) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      final index = cached.indexWhere((item) => item.id == id);
      if (index == -1) throw Exception('Task $id not found');
      final data = Map<String, dynamic>.from(cached[index].toJson())
        ..addAll(updates)
        ..['updated_at'] = DateTime.now().toIso8601String();
      final updated = TaskModel.fromJson(data);
      final next = [...cached]..[index] = updated;
      await _writeCache(next);
      return updated;
    }

    updates['updated_at'] = DateTime.now().toIso8601String();
    updates['firebase_uid'] = _uid;
    await _firestore.collection('tasks').doc(id.toString()).update(updates);

    final doc = await _firestore.collection('tasks').doc(id.toString()).get();
    final task = TaskModel.fromJson(doc.data()!);

    final cached = await _readCache();
    await _writeCache([
      for (final item in cached)
        if (item.id == id) task else item,
    ]);
    return task;
  }

  Future<void> deleteTask(int id) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache(cached.where((item) => item.id != id).toList());
      return;
    }

    await _firestore.collection('tasks').doc(id.toString()).delete();
    final cached = await _readCache();
    await _writeCache(cached.where((item) => item.id != id).toList());
  }

  Future<TaskModel> archiveTask(int id) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache(cached.where((item) => item.id != id).toList());
      final index = cached.indexWhere((item) => item.id == id);
      if (index != -1) return cached[index];
      throw Exception('Task $id not found');
    }

    final doc = await _firestore.collection('tasks').doc(id.toString()).get();
    final task = TaskModel.fromJson(doc.data()!);
    await _firestore.collection('tasks').doc(id.toString()).delete();

    final cached = await _readCache();
    await _writeCache(cached.where((item) => item.id != id).toList());
    return task;
  }

  Future<TaskModel> toggleComplete(int id) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      final index = cached.indexWhere((item) => item.id == id);
      if (index == -1) throw Exception('Task $id not found');
      final data = Map<String, dynamic>.from(cached[index].toJson())
        ..['is_complete'] = !cached[index].isComplete
        ..['updated_at'] = DateTime.now().toIso8601String();
      final updated = TaskModel.fromJson(data);
      final next = [...cached]..[index] = updated;
      await _writeCache(next);
      return updated;
    }

    final docRef = _firestore.collection('tasks').doc(id.toString());
    return await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Task $id not found');

      final currentData = snapshot.data()!;
      final updatedIsComplete = !(currentData['is_complete'] as bool? ?? false);

      transaction.update(docRef, {
        'is_complete': updatedIsComplete,
        'updated_at': DateTime.now().toIso8601String(),
        'firebase_uid': _uid,
      });

      currentData['is_complete'] = updatedIsComplete;
      currentData['updated_at'] = DateTime.now().toIso8601String();
      final updatedTask = TaskModel.fromJson(currentData);

      final cached = await _readCache();
      await _writeCache([
        for (final item in cached)
          if (item.id == id) updatedTask else item,
      ]);
      return updatedTask;
    });
  }

  Future<TaskModel> patchSubtasks(
    int id,
    List<Map<String, dynamic>> subtasks,
  ) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      final index = cached.indexWhere((item) => item.id == id);
      if (index == -1) throw Exception('Task $id not found');
      final data = Map<String, dynamic>.from(cached[index].toJson())
        ..['subtasks'] = subtasks
        ..['updated_at'] = DateTime.now().toIso8601String();
      final updated = TaskModel.fromJson(data);
      final next = [...cached]..[index] = updated;
      await _writeCache(next);
      return updated;
    }

    await _firestore.collection('tasks').doc(id.toString()).update({
      'subtasks': subtasks,
      'updated_at': DateTime.now().toIso8601String(),
      'firebase_uid': _uid,
    });

    final doc = await _firestore.collection('tasks').doc(id.toString()).get();
    final task = TaskModel.fromJson(doc.data()!);

    final cached = await _readCache();
    await _writeCache([
      for (final item in cached)
        if (item.id == id) task else item,
    ]);
    return task;
  }

  Future<TaskModel> createFromCalendarDay({
    required String title,
    required DateTime day,
    int? projectId,
    String? description,
  }) async {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch;
    final task = TaskModel(
      id: id,
      userId: _userId == 0 ? demoUser.id : _userId,
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

    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache([task, ...cached.where((item) => item.id != task.id)]);
      return task;
    }

    await _firestore
        .collection('tasks')
        .doc(id.toString())
        .set(withFirebaseOwner(task.toJson(), _uid));

    final cached = await _readCache();
    await _writeCache([task, ...cached.where((item) => item.id != task.id)]);
    return task;
  }

  Future<List<TaskModel>> _readCache() async {
    if (_uid == null || kEnableOfflineTestingMode) {
      return (await _cache.readDemoJsonList(DemoCacheKey.tasks))
          .map(TaskModel.fromJson)
          .toList();
    }
    final cached = await _cache.readJsonListForUser(
      _session!,
      CacheKeys.tasks(_uid),
    );
    return cached.map(TaskModel.fromJson).toList();
  }

  Future<List<TaskModel>> _readOrSeedCache() async {
    final cached = await _readCache();
    if (cached.isNotEmpty) return cached;
    final seed = _applyFilters(buildDemoTasks());
    await _writeCache(seed);
    return seed;
  }

  Future<void> _writeCache(List<TaskModel> tasks) {
    final values = tasks.map((task) => task.toJson()).toList();
    if (_uid == null || kEnableOfflineTestingMode) {
      return _cache.saveDemoJsonList(DemoCacheKey.tasks, values);
    }
    return _cache.saveJsonListForUser(_session!, CacheKeys.tasks(_uid), values);
  }

  List<TaskModel> _applyFilters(
    List<TaskModel> tasks, {
    TaskPriority? priority,
    int? projectId,
    bool? isComplete,
  }) {
    var filtered = tasks;
    if (priority != null) {
      filtered = filtered.where((task) => task.priority == priority).toList();
    }
    if (projectId != null) {
      filtered = filtered.where((task) => task.projectId == projectId).toList();
    }
    if (isComplete != null) {
      filtered =
          filtered.where((task) => task.isComplete == isComplete).toList();
    }
    filtered.sort((a, b) {
      if (a.isComplete != b.isComplete) return a.isComplete ? 1 : -1;
      if (a.deadline == null && b.deadline == null) {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (a.deadline == null) return 1;
      if (b.deadline == null) return -1;
      return a.deadline!.compareTo(b.deadline!);
    });
    return filtered;
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(
    ref.watch(localCacheServiceProvider),
    ref.watch(activeAccountUidProvider),
  ),
);
