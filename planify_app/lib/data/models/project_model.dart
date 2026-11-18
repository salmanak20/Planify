import 'json_helpers.dart';

/// Project / Workspace data model.
class ProjectModel {
  final int id;
  final int userId;
  final int? parentProjectId;
  final String name;
  final String? description;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectModel({
    required this.id,
    required this.userId,
    this.parentProjectId,
    required this.name,
    this.description,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) => ProjectModel(
        id: jsonInt(json['id']),
        userId: jsonInt(json['user_id']),
        parentProjectId: jsonNullableInt(json['parent_project_id']),
        name: json['name'] as String? ?? 'Untitled project',
        description: json['description'] as String?,
        color: json['color'] as String? ?? '#435f92',
        createdAt: jsonDateTime(json['created_at']),
        updatedAt: jsonDateTime(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'parent_project_id': parentProjectId,
        'name': name,
        'description': description,
        'color': color,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
