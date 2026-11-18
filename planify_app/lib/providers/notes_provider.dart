import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/data/models/note_model.dart';
import 'package:planify_app/data/repositories/notes_repository.dart';

class NotesNotifier extends StateNotifier<AsyncValue<List<NoteModel>>> {
  final NotesRepository _repo;

  NotesNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({String? search, String? folder, String? tag}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.getNotes(search: search, folder: folder, tag: tag),
    );
  }

  Future<void> create({
    required String title,
    String? content,
    String color = '#ffffff',
    String? folder,
    List<String> tags = const [],
    int? projectId,
  }) async {
    final now = DateTime.now();
    final tempId = -now.microsecondsSinceEpoch;
    final optimistic = NoteModel(
      id: tempId,
      userId: 0,
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
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([optimistic, ...current]);

    try {
      final note = await _repo.createNote(
        title: title,
        content: content,
        color: color,
        folder: folder,
        tags: tags,
        projectId: projectId,
      );
      final latest = state.valueOrNull ?? [];
      state = AsyncValue.data([
        note,
        ...latest.where((item) => item.id != tempId && item.id != note.id),
      ]);
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
      final updated = await _repo.updateNote(
        id,
        Map<String, dynamic>.from(updates),
      );
      state = AsyncValue.data([updated, ...current]);
      return;
    }

    final optimistic = _applyUpdates(original, updates);
    state = AsyncValue.data(
      current.map((note) => note.id == id ? optimistic : note).toList(),
    );

    try {
      final updated = await _repo.updateNote(
        id,
        Map<String, dynamic>.from(updates),
      );
      final latest = state.valueOrNull ?? [];
      state = AsyncValue.data(
        latest.map((note) => note.id == id ? updated : note).toList(),
      );
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((note) => note.id != id).toList());

    try {
      await _repo.deleteNote(id);
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  Future<void> togglePin(int id) async {
    final updated = await _repo.togglePin(id);
    state.whenData((notes) {
      final newList = notes.map((n) => n.id == id ? updated : n).toList();
      // Re-sort: pinned first
      newList.sort((a, b) {
        if (a.isPinned == b.isPinned) return b.updatedAt.compareTo(a.updatedAt);
        return a.isPinned ? -1 : 1;
      });
      state = AsyncValue.data(newList);
    });
  }

  NoteModel? _findById(List<NoteModel> notes, int id) {
    for (final note in notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  NoteModel _applyUpdates(NoteModel note, Map<String, dynamic> updates) {
    final data = Map<String, dynamic>.from(note.toJson())
      ..addAll(updates)
      ..['updated_at'] = DateTime.now().toIso8601String();
    return NoteModel.fromJson(data);
  }
}

final notesProvider =
    StateNotifierProvider<NotesNotifier, AsyncValue<List<NoteModel>>>(
  (ref) => NotesNotifier(ref.watch(notesRepositoryProvider)),
);
