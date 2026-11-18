class DashboardSummaryModel {
  final List<DashboardTaskItemModel> todayTasks;
  final List<DashboardEventItemModel> upcomingEvents;
  final ActiveFocusSessionModel? activeFocusSession;
  final List<DashboardNoteItemModel> recentNotes;

  const DashboardSummaryModel({
    required this.todayTasks,
    required this.upcomingEvents,
    this.activeFocusSession,
    required this.recentNotes,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      todayTasks: (json['today_tasks'] as List<dynamic>? ?? [])
          .map(
              (e) => DashboardTaskItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      upcomingEvents: (json['upcoming_events'] as List<dynamic>? ?? [])
          .map((e) =>
              DashboardEventItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeFocusSession: json['active_focus_session'] == null
          ? null
          : ActiveFocusSessionModel.fromJson(
              json['active_focus_session'] as Map<String, dynamic>,
            ),
      recentNotes: (json['recent_notes'] as List<dynamic>? ?? [])
          .map(
              (e) => DashboardNoteItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DashboardTaskItemModel {
  final int id;
  final String title;
  final DateTime? deadline;
  final String priority;
  final bool isComplete;
  const DashboardTaskItemModel({
    required this.id,
    required this.title,
    required this.deadline,
    required this.priority,
    required this.isComplete,
  });
  factory DashboardTaskItemModel.fromJson(Map<String, dynamic> json) =>
      DashboardTaskItemModel(
        id: json['id'] as int,
        title: json['title'] as String,
        deadline: json['deadline'] == null
            ? null
            : DateTime.parse(json['deadline'] as String),
        priority: json['priority'] as String? ?? 'medium',
        isComplete: json['is_complete'] as bool? ?? false,
      );
}

class DashboardEventItemModel {
  final int id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final bool allDay;
  const DashboardEventItemModel({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.allDay,
  });
  factory DashboardEventItemModel.fromJson(Map<String, dynamic> json) =>
      DashboardEventItemModel(
        id: json['id'] as int,
        title: json['title'] as String,
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: DateTime.parse(json['end_time'] as String),
        allDay: json['all_day'] as bool? ?? false,
      );
}

class DashboardNoteItemModel {
  final int id;
  final String title;
  final DateTime updatedAt;
  final bool isPinned;
  const DashboardNoteItemModel({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.isPinned,
  });
  factory DashboardNoteItemModel.fromJson(Map<String, dynamic> json) =>
      DashboardNoteItemModel(
        id: json['id'] as int,
        title: json['title'] as String,
        updatedAt: DateTime.parse(json['updated_at'] as String),
        isPinned: json['is_pinned'] as bool? ?? false,
      );
}

class ActiveFocusSessionModel {
  final int? taskId;
  final String? taskTitle;
  final DateTime? startedAt;
  final int? remainingSeconds;
  const ActiveFocusSessionModel({
    this.taskId,
    this.taskTitle,
    this.startedAt,
    this.remainingSeconds,
  });
  factory ActiveFocusSessionModel.fromJson(Map<String, dynamic> json) =>
      ActiveFocusSessionModel(
        taskId: json['task_id'] as int?,
        taskTitle: json['task_title'] as String?,
        startedAt: json['started_at'] == null
            ? null
            : DateTime.parse(json['started_at'] as String),
        remainingSeconds: json['remaining_seconds'] as int?,
      );
}

class ProjectAnalyticsModel {
  final int projectId;
  final double progressPercent;
  final int completedTasks;
  final int overdueItems;
  final List<ProjectActivityModel> recentActivity;
  const ProjectAnalyticsModel({
    required this.projectId,
    required this.progressPercent,
    required this.completedTasks,
    required this.overdueItems,
    required this.recentActivity,
  });
  factory ProjectAnalyticsModel.fromJson(Map<String, dynamic> json) =>
      ProjectAnalyticsModel(
        projectId: json['project_id'] as int,
        progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0,
        completedTasks: json['completed_tasks'] as int? ?? 0,
        overdueItems: json['overdue_items'] as int? ?? 0,
        recentActivity: (json['recent_activity'] as List<dynamic>? ?? [])
            .map(
                (e) => ProjectActivityModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ProjectActivityModel {
  final String itemType;
  final int itemId;
  final String title;
  final DateTime timestamp;
  const ProjectActivityModel({
    required this.itemType,
    required this.itemId,
    required this.title,
    required this.timestamp,
  });
  factory ProjectActivityModel.fromJson(Map<String, dynamic> json) =>
      ProjectActivityModel(
        itemType: json['item_type'] as String,
        itemId: json['item_id'] as int,
        title: json['title'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class SearchGroupModel {
  final List<SearchItemModel> tasks;
  final List<SearchItemModel> notes;
  final List<SearchItemModel> events;
  final List<SearchItemModel> projects;
  const SearchGroupModel({
    required this.tasks,
    required this.notes,
    required this.events,
    required this.projects,
  });
  factory SearchGroupModel.fromJson(Map<String, dynamic> json) =>
      SearchGroupModel(
        tasks: _parse(json['tasks']),
        notes: _parse(json['notes']),
        events: _parse(json['events']),
        projects: _parse(json['projects']),
      );

  static List<SearchItemModel> _parse(dynamic value) {
    return (value as List<dynamic>? ?? [])
        .map((e) => SearchItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class SearchItemModel {
  final int id;
  final String type;
  final String title;
  final String? subtitle;
  final int? projectId;
  const SearchItemModel({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.projectId,
  });
  factory SearchItemModel.fromJson(Map<String, dynamic> json) =>
      SearchItemModel(
        id: json['id'] as int,
        type: json['type'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        projectId: json['project_id'] as int?,
      );
}
