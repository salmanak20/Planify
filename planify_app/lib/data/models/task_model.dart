import 'json_helpers.dart';

/// Task priority levels.
enum TaskPriority { low, medium, high }

extension TaskPriorityX on TaskPriority {
  String get label => name[0].toUpperCase() + name.substring(1);
  String get apiValue => name;

  static TaskPriority fromString(String s) => TaskPriority.values
      .firstWhere((e) => e.name == s, orElse: () => TaskPriority.medium);
}

/// Subtask (simplified task without nesting).
class SubtaskModel {
  final int id;
  final String title;
  final bool isComplete;

  const SubtaskModel(
      {required this.id, required this.title, required this.isComplete});

  factory SubtaskModel.fromJson(Map<String, dynamic> json) => SubtaskModel(
        id: jsonInt(json['id']),
        title: json['title'] as String? ?? '',
        isComplete: json['is_complete'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'is_complete': isComplete,
      };

  SubtaskModel copyWith({
    int? id,
    String? title,
    bool? isComplete,
  }) =>
      SubtaskModel(
        id: id ?? this.id,
        title: title ?? this.title,
        isComplete: isComplete ?? this.isComplete,
      );
}

/// Task data model stored in Firestore.
class TaskModel {
  final int id;
  final int userId;
  final int? projectId;
  final int? eventId;
  final int? parentTaskId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final bool isComplete;
  final List<String> tags;
  final DateTime? deadline;
  final DateTime? reminderAt;
  final List<SubtaskModel> subtasks;
  final int? sourceNoteId;
  final String? sourceNoteLine;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskModel({
    required this.id,
    required this.userId,
    this.projectId,
    this.eventId,
    this.parentTaskId,
    required this.title,
    this.description,
    required this.priority,
    required this.isComplete,
    required this.tags,
    this.deadline,
    this.reminderAt,
    required this.subtasks,
    this.sourceNoteId,
    this.sourceNoteLine,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: jsonInt(json['id']),
        userId: jsonInt(json['user_id']),
        projectId: jsonNullableInt(json['project_id']),
        eventId: jsonNullableInt(json['event_id']),
        parentTaskId: jsonNullableInt(json['parent_task_id']),
        title: json['title'] as String? ?? 'Untitled task',
        description: json['description'] as String?,
        priority:
            TaskPriorityX.fromString(json['priority'] as String? ?? 'medium'),
        isComplete: json['is_complete'] as bool? ?? false,
        tags: jsonStringList(json['tags']),
        deadline: jsonNullableDateTime(json['deadline']),
        reminderAt: jsonNullableDateTime(json['reminder_at']),
        subtasks: (json['subtasks'] as List<dynamic>?)
                ?.whereType<Map>()
                .map((e) => SubtaskModel.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        createdAt: jsonDateTime(json['created_at']),
        updatedAt: jsonDateTime(json['updated_at']),
        sourceNoteId: jsonNullableInt(json['source_note_id']),
        sourceNoteLine: json['source_note_line'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'project_id': projectId,
        'event_id': eventId,
        'parent_task_id': parentTaskId,
        'title': title,
        'description': description,
        'priority': priority.apiValue,
        'is_complete': isComplete,
        'tags': tags,
        'deadline': deadline?.toIso8601String(),
        'reminder_at': reminderAt?.toIso8601String(),
        'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
        if (sourceNoteId != null) 'source_note_id': sourceNoteId,
        if (sourceNoteLine != null) 'source_note_line': sourceNoteLine,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  TaskModel copyWith({
    bool? isComplete,
    String? title,
    String? description,
    TaskPriority? priority,
    DateTime? deadline,
    DateTime? reminderAt,
    List<String>? tags,
    int? projectId,
    int? eventId,
    int? parentTaskId,
    int? sourceNoteId,
    String? sourceNoteLine,
    List<SubtaskModel>? subtasks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      TaskModel(
        id: id,
        userId: userId,
        projectId: projectId ?? this.projectId,
        eventId: eventId ?? this.eventId,
        parentTaskId: parentTaskId ?? this.parentTaskId,
        title: title ?? this.title,
        description: description ?? this.description,
        priority: priority ?? this.priority,
        isComplete: isComplete ?? this.isComplete,
        tags: tags ?? this.tags,
        deadline: deadline ?? this.deadline,
        reminderAt: reminderAt ?? this.reminderAt,
        subtasks: subtasks ?? this.subtasks,
        sourceNoteId: sourceNoteId ?? this.sourceNoteId,
        sourceNoteLine: sourceNoteLine ?? this.sourceNoteLine,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
