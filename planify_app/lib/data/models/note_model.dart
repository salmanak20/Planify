import 'json_helpers.dart';

/// Note data model stored in Firestore.
class NoteModel {
  final int id;
  final int userId;
  final int? projectId;
  final String title;
  final String? content;
  final String color;
  final bool isPinned;
  final String? folder;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteModel({
    required this.id,
    required this.userId,
    this.projectId,
    required this.title,
    this.content,
    required this.color,
    required this.isPinned,
    this.folder,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
        id: jsonInt(json['id']),
        userId: jsonInt(json['user_id']),
        projectId: jsonNullableInt(json['project_id']),
        title: json['title'] as String? ?? 'Untitled',
        content: json['content'] as String?,
        color: json['color'] as String? ?? '#ffffff',
        isPinned: json['is_pinned'] as bool? ?? false,
        folder: json['folder'] as String?,
        tags: jsonStringList(json['tags']),
        createdAt: jsonDateTime(json['created_at']),
        updatedAt: jsonDateTime(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'project_id': projectId,
        'title': title,
        'content': content,
        'color': color,
        'is_pinned': isPinned,
        'folder': folder,
        'tags': tags,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  NoteModel copyWith({
    int? id,
    int? userId,
    int? projectId,
    String? title,
    String? content,
    String? color,
    bool? isPinned,
    String? folder,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      NoteModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        projectId: projectId ?? this.projectId,
        title: title ?? this.title,
        content: content ?? this.content,
        color: color ?? this.color,
        isPinned: isPinned ?? this.isPinned,
        folder: folder ?? this.folder,
        tags: tags ?? this.tags,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
