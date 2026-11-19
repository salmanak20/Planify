import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/constants/app_flags.dart';
import 'package:planify_app/core/utils/firebase_identity.dart';
import 'package:planify_app/data/datasources/cache_keys.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/data/mock/demo_data.dart';
import 'package:planify_app/data/models/project_model.dart';
import 'package:planify_app/data/models/task_model.dart';
import 'package:planify_app/data/models/note_model.dart';
import 'package:planify_app/providers/account_scope_provider.dart';

class ProjectsRepository {
  final LocalCacheService _cache;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String? _uid;
  final CacheSession? _session;

  ProjectsRepository(this._cache, this._uid)
      : _session = _uid == null ? null : _cache.captureSession(_uid);

  int get _userId => currentStableUserId(_auth) ?? 0;

  Future<List<ProjectModel>> getProjects() async {
    if (kEnableOfflineTestingMode || _uid == null) {
      return _readOrSeedCache();
    }

    try {
      _requireActiveUid();
      final snapshot = await ownedQuery(_firestore, 'projects', _uid).get();
      _requireActiveUid();
      final projects = snapshot.docs
          .map((doc) => ProjectModel.fromJson(doc.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _writeCache(projects);
      return projects;
    } catch (_) {
      _requireActiveUid();
      final cached = await _readCache();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<ProjectModel> createProject({
    required String name,
    String? description,
    String color = '#435f92',
    int? parentProjectId,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final project = ProjectModel(
      id: id,
      userId: _userId == 0 ? demoUser.id : _userId,
      parentProjectId: parentProjectId,
      name: name,
      description: description,
      color: color,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache([project, ...cached.where((item) => item.id != id)]);
      return project;
    }

    _requireActiveUid();
    await _firestore
        .collection('projects')
        .doc(id.toString())
        .set(withFirebaseOwner(project.toJson(), _uid));

    _requireActiveUid();
    final cached = await _readCache();
    await _writeCache([project, ...cached.where((item) => item.id != id)]);
    return project;
  }

  Future<ProjectModel> updateProject(
      int id, Map<String, dynamic> updates) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      final updated = _applyUpdates(cached, id, updates);
      await _writeCache(_replaceProject(cached, updated));
      return updated;
    }

    updates['updated_at'] = DateTime.now().toIso8601String();
    updates['firebase_uid'] = _uid;
    _requireActiveUid();
    await _firestore.collection('projects').doc(id.toString()).update(updates);
    _requireActiveUid();
    final doc =
        await _firestore.collection('projects').doc(id.toString()).get();
    _requireActiveUid();
    final project = ProjectModel.fromJson(doc.data()!);

    final cached = await _readCache();
    await _writeCache(_replaceProject(cached, project));
    return project;
  }

  Future<void> deleteProject(int id) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache(cached.where((project) => project.id != id).toList());
      return;
    }

    final uid = _uid;
    final batch = _firestore.batch();

    _requireActiveUid();
    final tasksSnap = await ownedQuery(_firestore, 'tasks', uid).get();
    _requireActiveUid();
    for (final doc in tasksSnap.docs) {
      final data = doc.data();
      if (data['project_id'] == id) {
        batch.update(doc.reference, {
          'project_id': null,
          'firebase_uid': uid,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }

    final notesSnap = await ownedQuery(_firestore, 'notes', uid).get();
    _requireActiveUid();
    for (final doc in notesSnap.docs) {
      final data = doc.data();
      if (data['project_id'] == id) {
        batch.update(doc.reference, {
          'project_id': null,
          'firebase_uid': uid,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }

    batch.delete(_firestore.collection('projects').doc(id.toString()));
    _requireActiveUid();
    await batch.commit();

    _requireActiveUid();
    final cached = await _readCache();
    await _writeCache(cached.where((project) => project.id != id).toList());
  }

  Future<List<TaskModel>> getProjectTasks(int id) async {
    final uid = _requireActiveUid();
    final snapshot = await ownedQuery(_firestore, 'tasks', uid).get();
    _requireActiveUid();
    return snapshot.docs
        .map((doc) => TaskModel.fromJson(doc.data()))
        .where((task) => task.projectId == id)
        .toList();
  }

  Future<List<NoteModel>> getProjectNotes(int id) async {
    final uid = _requireActiveUid();
    final snapshot = await ownedQuery(_firestore, 'notes', uid).get();
    _requireActiveUid();
    return snapshot.docs
        .map((doc) => NoteModel.fromJson(doc.data()))
        .where((note) => note.projectId == id)
        .toList();
  }

  String _requireActiveUid() {
    final uid = requireActiveFirebaseUid(_auth, _uid);
    _cache.ensureSessionCurrent(_session!);
    return uid;
  }

  Future<List<ProjectModel>> _readCache() async {
    if (_uid == null || kEnableOfflineTestingMode) {
      return (await _cache.readDemoJsonList(DemoCacheKey.projects))
          .map(ProjectModel.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final cached = await _cache.readJsonListForUser(
      _session!,
      CacheKeys.projects(_uid),
    );
    final projects = cached.map(ProjectModel.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return projects;
  }

  Future<List<ProjectModel>> _readOrSeedCache() async {
    final cached = await _readCache();
    if (cached.isNotEmpty) return cached;
    final seed = buildDemoProjects()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _writeCache(seed);
    return seed;
  }

  Future<void> _writeCache(List<ProjectModel> projects) {
    final values = projects.map((project) => project.toJson()).toList();
    if (_uid == null || kEnableOfflineTestingMode) {
      return _cache.saveDemoJsonList(DemoCacheKey.projects, values);
    }
    return _cache.saveJsonListForUser(
      _session!,
      CacheKeys.projects(_uid),
      values,
    );
  }

  ProjectModel _applyUpdates(
    List<ProjectModel> projects,
    int id,
    Map<String, dynamic> updates,
  ) {
    final index = projects.indexWhere((project) => project.id == id);
    if (index == -1) throw Exception('Project $id not found');
    final data = Map<String, dynamic>.from(projects[index].toJson())
      ..addAll(updates)
      ..['updated_at'] = DateTime.now().toIso8601String();
    return ProjectModel.fromJson(data);
  }

  List<ProjectModel> _replaceProject(
    List<ProjectModel> projects,
    ProjectModel project,
  ) {
    final next = [
      project,
      ...projects.where((item) => item.id != project.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return next;
  }
}

final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => ProjectsRepository(
    ref.watch(localCacheServiceProvider),
    ref.watch(activeAccountUidProvider),
  ),
);
