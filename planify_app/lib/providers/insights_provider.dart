import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/data/models/insights_model.dart';
import 'package:planify_app/data/repositories/insights_repository.dart';
import 'package:planify_app/providers/tasks_provider.dart';
import 'package:planify_app/providers/notes_provider.dart';

final dashboardSummaryProvider =
    FutureProvider<DashboardSummaryModel>((ref) async {
  return ref.watch(insightsRepositoryProvider).getDashboardSummary();
});

final projectAnalyticsProvider =
    FutureProvider.family<ProjectAnalyticsModel, int>((ref, projectId) async {
  return ref.watch(insightsRepositoryProvider).getProjectAnalytics(projectId);
});

final globalSearchProvider = FutureProvider.family<SearchGroupModel, String>(
  (ref, query) async {
    if (query.trim().isEmpty) {
      return const SearchGroupModel(
          tasks: [], notes: [], events: [], projects: []);
    }
    return ref.watch(insightsRepositoryProvider).searchAll(query.trim());
  },
);

final smartInsightProvider = FutureProvider<String>((ref) async {
  final tasks = ref.watch(tasksProvider).value ?? [];
  final notes = ref.watch(notesProvider).value ?? [];
  final pendingTasks = tasks.where((t) => !t.isComplete).toList();
  return ref
      .watch(insightsRepositoryProvider)
      .generateSmartInsight(pendingTasks, notes);
});
