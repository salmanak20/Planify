import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/data/models/note_model.dart';
import 'package:planify_app/providers/notes_provider.dart';

const _noteCategoriesCacheKey = 'note_categories_cache';

class NoteCategoriesNotifier extends StateNotifier<AsyncValue<List<String>>> {
  NoteCategoriesNotifier(this._ref, this._cache)
      : super(const AsyncValue.loading()) {
    load();
    _ref.listen<AsyncValue<List<NoteModel>>>(
      notesProvider,
      (_, __) => load(),
    );
  }

  final Ref _ref;
  final LocalCacheService _cache;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final cached = await _cache.readStringList(_noteCategoriesCacheKey);
      final noteCategories = (_ref.read(notesProvider).valueOrNull ?? const [])
          .map((note) => note.folder?.trim())
          .whereType<String>()
          .where((folder) => folder.isNotEmpty)
          .toSet();
      final categories = {...cached, ...noteCategories}.toList()..sort();
      await _cache.saveStringList(_noteCategoriesCacheKey, categories);
      return categories;
    });
  }

  Future<void> create(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    final current = {...(state.valueOrNull ?? const <String>[]), normalized}
      ..removeWhere((item) => item.trim().isEmpty);
    final next = current.toList()..sort();
    await _cache.saveStringList(_noteCategoriesCacheKey, next);
    state = AsyncValue.data(next);
  }

  Future<void> rename(String previousName, String nextName) async {
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
    await _cache.saveStringList(_noteCategoriesCacheKey, next);
    state = AsyncValue.data(next);
  }

  Future<void> delete(String name) async {
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
    await _cache.saveStringList(_noteCategoriesCacheKey, current);
    state = AsyncValue.data(current);
  }
}

final noteCategoriesProvider =
    StateNotifierProvider<NoteCategoriesNotifier, AsyncValue<List<String>>>(
  (ref) => NoteCategoriesNotifier(
    ref,
    ref.watch(localCacheServiceProvider),
  ),
);
