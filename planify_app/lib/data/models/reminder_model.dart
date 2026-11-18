import 'json_helpers.dart';

/// Repeat options for standalone reminders.
enum ReminderRepeat {
  none,
  daily,
  weekly,
  monthly;

  String get apiValue => name;

  String get label => switch (this) {
        ReminderRepeat.none => 'Once',
        ReminderRepeat.daily => 'Daily',
        ReminderRepeat.weekly => 'Weekly',
        ReminderRepeat.monthly => 'Monthly',
      };

  static ReminderRepeat fromString(String? value) {
    return ReminderRepeat.values.firstWhere(
      (r) => r.name == value,
      orElse: () => ReminderRepeat.none,
    );
  }
}

/// Standalone quick-reminder data model.
class ReminderModel {
  final int id;
  final int userId;
  final String title;
  final String? notes;
  final DateTime reminderTime;
  final bool isCompleted;
  final ReminderRepeat repeat;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReminderModel({
    required this.id,
    required this.userId,
    required this.title,
    this.notes,
    required this.reminderTime,
    required this.isCompleted,
    this.repeat = ReminderRepeat.none,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) => ReminderModel(
        id: jsonInt(json['id']),
        userId: jsonInt(json['user_id']),
        title: json['title'] as String? ?? 'Untitled reminder',
        notes: json['notes'] as String?,
        reminderTime: jsonDateTime(json['reminder_time']),
        isCompleted: json['is_completed'] as bool? ?? false,
        repeat: ReminderRepeat.fromString(json['repeat'] as String?),
        createdAt: jsonDateTime(json['created_at']),
        updatedAt: jsonDateTime(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'notes': notes,
        'reminder_time': reminderTime.toIso8601String(),
        'is_completed': isCompleted,
        'repeat': repeat.apiValue,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ReminderModel copyWith({
    int? id,
    int? userId,
    String? title,
    String? notes,
    DateTime? reminderTime,
    bool? isCompleted,
    ReminderRepeat? repeat,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      reminderTime: reminderTime ?? this.reminderTime,
      isCompleted: isCompleted ?? this.isCompleted,
      repeat: repeat ?? this.repeat,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
