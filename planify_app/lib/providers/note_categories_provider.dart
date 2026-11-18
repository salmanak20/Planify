import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/data/models/note_model.dart';
import 'package:planify_app/providers/notes_provider.dart';
import 'package:planify_app/data/datasources/cache_keys.dart';
import 'package:planify_app/providers/account_scope_provider.dart';
import 'package:planify_app/providers/account_scoped_notifier.dart';

class NoteCategoriesNotifier
    extends AccountScopedStateNotifier<AsyncValue<List<String>>> {
  NoteCategoriesNotifier(this._ref, this._cache, this._uid)
      : super(_uid == null
            ? const AsyncValue.data([])
            : const AsyncValue.loading()) {
    if (_uid != null) {
      load();
      _ref.listen<AsyncValue<List<NoteModel>>>(
        notesProvider,
        (_, __) => load(),
      );
    }
  }

  final Ref _ref;
  final LocalCacheService _cache;
  final String? _uid;

  Future<void> load() async {
    if (_uid == null) {
      state = const AsyncValue.data([]);
      return;
    }
    final session = _cache.captureSession(_uid);
    final cacheKey = CacheKeys.noteCategories(_uid);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final cached = await _cache.readStringListForUser(session, cacheKey);
      final noteCategories = (_ref.read(notesProvider).valueOrNull ?? const [])
          .map((note) => note.folder?.trim())
          .whereType<String>()
          .where((folder) => folder.isNotEmpty)
          .toSet();
      final categories = {...cached, ...noteCategories}.toList()..sort();
      await _cache.saveStringListForUser(session, cacheKey, categories);
      return categories;
    });
  }

  Future<void> create(String name) async {
    final session = _requireSession();
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    final current = {...(state.valueOrNull ?? const <String>[]), normalized}
      ..removeWhere((item) => item.trim().isEmpty);
    final next = current.toList()..sort();
    await _cache.saveStringListForUser(
      session,
      CacheKeys.noteCategories(session.uid),
      next,
    );
    state = AsyncValue.data(next);
  }

  Future<void> rename(String previousName, String nextName) async {
    final session = _requireSession();
    final oldValue = previousName.trim();
    final newValue = nextName.trim();
    if (oldValue.isEmpty || newValue.isEmpty || oldValue == newValue) return;

    final notes = _ref.read(notesProvider).valueOrNull ?? const [];
    for (final note in notes.where((item) => item.folder == oldValue)) {
      await _ref.read(notesProvider.notifier).update(note.id, {
        'folder': newValue,
      });
    }

    final current = {...(state.valueOrNull ?? const <String>[])}
      ..remove(oldValue);
    current.add(newValue);
    final next = current.toList()..sort();
    await _cache.saveStringListForUser(
      session,
      CacheKeys.noteCategories(session.uid),
      next,
    );
    state = AsyncValue.data(next);
  }

  Future<void> delete(String name) async {
    final session = _requireSession();
    final normalized = name.trim();
    if (normalized.isEmpty) return;

    final notes = _ref.read(notesProvider).valueOrNull ?? const [];
    for (final note in notes.where((item) => item.folder == normalized)) {
      await _ref.read(notesProvider.notifier).update(note.id, {
        'folder': null,
      });
    }

    final current = [...(state.valueOrNull ?? const <String>[])]
      ..removeWhere((item) => item == normalized);
    await _cache.saveStringListForUser(
      session,
      CacheKeys.noteCategories(session.uid),
      current,
    );
    state = AsyncValue.data(current);
  }

  CacheSession _requireSession() {
    final uid = _uid;
    if (uid == null) throw const CacheSessionInvalidatedException();
    return _cache.captureSession(uid);
  }
}

final noteCategoriesProvider =
    StateNotifierProvider<NoteCategoriesNotifier, AsyncValue<List<String>>>(
  (ref) => NoteCategoriesNotifier(
    ref,
    ref.watch(localCacheServiceProvider),
    ref.watch(activeAccountUidProvider),
  ),
);
