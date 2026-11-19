import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/data/models/project_model.dart';
import 'package:planify_app/data/repositories/projects_repository.dart';
import 'package:planify_app/providers/account_scope_provider.dart';
import 'package:planify_app/providers/account_scoped_notifier.dart';

class ProjectsNotifier
    extends AccountScopedStateNotifier<AsyncValue<List<ProjectModel>>> {
  final ProjectsRepository _repo;
  final String? _accountUid;

  ProjectsNotifier(this._repo, this._accountUid)
      : super(_accountUid == null
            ? const AsyncValue.data([])
            : const AsyncValue.loading()) {
    if (_accountUid != null) load();
  }

  Future<void> load() async {
    if (_accountUid == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repo.getProjects());
    if (mounted) state = result;
  }

  Future<void> create(
      {required String name,
      String? description,
      String color = '#435f92'}) async {
    final project = await _repo.createProject(
        name: name, description: description, color: color);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
        [project, ...current.where((item) => item.id != project.id)]);
  }

  Future<void> update(int id, Map<String, dynamic> updates) async {
    final updated = await _repo.updateProject(id, updates);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((project) => project.id == id ? updated : project).toList(),
    );
  }

  Future<void> delete(int id) async {
    await _repo.deleteProject(id);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.where((project) => project.id != id).toList(),
    );
  }
}

final projectsProvider =
    StateNotifierProvider<ProjectsNotifier, AsyncValue<List<ProjectModel>>>(
  (ref) => ProjectsNotifier(
    ref.watch(projectsRepositoryProvider),
    ref.watch(activeAccountUidProvider),
  ),
);
