import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/data/models/project_model.dart';
import 'package:planify_app/data/repositories/projects_repository.dart';

class ProjectsNotifier extends StateNotifier<AsyncValue<List<ProjectModel>>> {
  final ProjectsRepository _repo;

  ProjectsNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getProjects());
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
  (ref) => ProjectsNotifier(ref.watch(projectsRepositoryProvider)),
);
