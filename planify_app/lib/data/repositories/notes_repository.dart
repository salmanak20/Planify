import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/constants/app_flags.dart';
import 'package:planify_app/core/utils/firebase_identity.dart';
import 'package:planify_app/data/datasources/cache_keys.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/data/mock/demo_data.dart';
import 'package:planify_app/data/models/note_model.dart';
import 'package:planify_app/data/models/task_model.dart';
import 'package:planify_app/providers/account_scope_provider.dart';

class NotesRepository {
  final LocalCacheService _cache;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String? _uid;
  final CacheSession? _session;

  NotesRepository(this._cache, this._uid)
      : _session = _uid == null ? null : _cache.captureSession(_uid);

  int get _userId => currentStableUserId(_auth) ?? 0;

  Future<List<NoteModel>> getNotes({
    String? search,
    String? folder,
    String? tag,
    int? projectId,
  }) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      return _applyFilters(
        await _readOrSeedCache(),
        search: search,
        folder: folder,
        tag: tag,
        projectId: projectId,
      );
    }

    try {
      Query query = ownedQuery(_firestore, 'notes', _uid);
      final snapshot = await query.get();
      final notes = snapshot.docs
          .map((doc) => NoteModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      await _writeCache(notes);
      return _applyFilters(
        notes,
        search: search,
        folder: folder,
        tag: tag,
        projectId: projectId,
      );
    } catch (_) {
      final cached = await _readCache();
      if (cached.isNotEmpty) {
        return _applyFilters(
          cached,
          search: search,
          folder: folder,
          tag: tag,
          projectId: projectId,
        );
      }
      rethrow;
    }
  }

  List<NoteModel> _applyFilters(
    List<NoteModel> notes, {
    String? search,
    String? folder,
    String? tag,
    int? projectId,
  }) {
    var filtered = [...notes];
    if (folder != null) {
      filtered = filtered.where((n) => n.folder == folder).toList();
    }
    if (projectId != null) {
      filtered = filtered.where((n) => n.projectId == projectId).toList();
    }
    if (tag != null) {
      filtered = filtered.where((n) => n.tags.contains(tag)).toList();
    }

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      filtered = filtered
          .where((note) =>
              note.title.toLowerCase().contains(q) ||
              (note.content?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    filtered.sort((a, b) {
      if (a.isPinned == b.isPinned) {
        return b.updatedAt.compareTo(a.updatedAt);
      }
      return a.isPinned ? -1 : 1;
    });

    return filtered;
  }

  Future<NoteModel> createNote({
    required String title,
    String? content,
    String color = '#ffffff',
    String? folder,
    List<String> tags = const [],
    int? projectId,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now();
    final note = NoteModel(
      id: id,
      userId: _userId == 0 ? demoUser.id : _userId,
      projectId: projectId,
      title: title,
      content: content,
      color: color,
      isPinned: false,
      folder: folder,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );

    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache([note, ...cached.where((item) => item.id != id)]);
      return note;
    }

    await _firestore
        .collection('notes')
        .doc(id.toString())
        .set(withFirebaseOwner(note.toJson(), _uid));

    final cached = await _readCache();
    await _writeCache([note, ...cached.where((item) => item.id != id)]);
    return note;
  }

  Future<NoteModel> updateNote(int id, Map<String, dynamic> updates) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      final updated = _applyUpdate(cached, id, updates);
      await _writeCache(_replaceNote(cached, updated));
      return updated;
    }

    updates['updated_at'] = DateTime.now().toIso8601String();
    updates['firebase_uid'] = _uid;
    await _firestore.collection('notes').doc(id.toString()).update(updates);
    final doc = await _firestore.collection('notes').doc(id.toString()).get();
    final note = NoteModel.fromJson(doc.data()!);

    final cached = await _readCache();
    await _writeCache(_replaceNote(cached, note));
    return note;
  }

  Future<void> deleteNote(int id) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache(cached.where((note) => note.id != id).toList());
      return;
    }

    await _firestore.collection('notes').doc(id.toString()).delete();

    final cached = await _readCache();
    await _writeCache(cached.where((note) => note.id != id).toList());
  }

  Future<NoteModel> togglePin(int id) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      final index = cached.indexWhere((note) => note.id == id);
      if (index == -1) throw Exception('Note $id not found');
      final toggled = cached[index].copyWith(
        isPinned: !cached[index].isPinned,
        updatedAt: DateTime.now(),
      );
      await _writeCache(_replaceNote(cached, toggled));
      return toggled;
    }

    final docRef = _firestore.collection('notes').doc(id.toString());
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Note $id not found');
    final current = NoteModel.fromJson(doc.data()!);
    final toggled = current.copyWith(
      isPinned: !current.isPinned,
      updatedAt: DateTime.now(),
    );
    await docRef.update(withFirebaseOwner(toggled.toJson(), _uid));

    final cached = await _readCache();
    await _writeCache(_replaceNote(cached, toggled));
    return toggled;
  }

  Future<TaskModel> convertToTask(
    int noteId, {
    String? lineText,
    int? projectId,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now();
    final task = TaskModel(
      id: id,
      userId: _userId == 0 ? demoUser.id : _userId,
      projectId: projectId,
      title: lineText ?? 'New Task from Note',
      priority: TaskPriority.medium,
      isComplete: false,
      tags: [],
      subtasks: [],
      sourceNoteId: noteId,
      sourceNoteLine: lineText,
      createdAt: now,
      updatedAt: now,
    );
    await _firestore
        .collection('tasks')
        .doc(id.toString())
        .set(withFirebaseOwner(task.toJson(), _requireUid()));
    return task;
  }

  String _requireUid() {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    return uid;
  }

  Future<List<NoteModel>> _readCache() async {
    if (_uid == null || kEnableOfflineTestingMode) {
      return (await _cache.readDemoJsonList(DemoCacheKey.notes))
          .map(NoteModel.fromJson)
          .toList();
    }
    final cached = await _cache.readJsonListForUser(
      _session!,
      CacheKeys.notes(_uid),
    );
    return cached.map(NoteModel.fromJson).toList();
  }

  Future<List<NoteModel>> _readOrSeedCache() async {
    final cached = await _readCache();
    if (cached.isNotEmpty) return cached;
    final seed = buildDemoNotes();
    await _writeCache(seed);
    return seed;
  }

  Future<void> _writeCache(List<NoteModel> notes) {
    final values = notes.map((note) => note.toJson()).toList();
    if (_uid == null || kEnableOfflineTestingMode) {
      return _cache.saveDemoJsonList(DemoCacheKey.notes, values);
    }
    return _cache.saveJsonListForUser(_session!, CacheKeys.notes(_uid), values);
  }

  NoteModel _applyUpdate(
    List<NoteModel> notes,
    int id,
    Map<String, dynamic> updates,
  ) {
    final index = notes.indexWhere((note) => note.id == id);
    if (index == -1) throw Exception('Note $id not found');
    final data = Map<String, dynamic>.from(notes[index].toJson())
      ..addAll(updates)
      ..['updated_at'] = DateTime.now().toIso8601String();
    return NoteModel.fromJson(data);
  }

  List<NoteModel> _replaceNote(List<NoteModel> notes, NoteModel note) {
    return [
      note,
      ...notes.where((item) => item.id != note.id),
    ];
  }
}

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => NotesRepository(
    ref.watch(localCacheServiceProvider),
    ref.watch(activeAccountUidProvider),
  ),
);
