import 'json_helpers.dart';

enum EventRepeat {
  none,
  daily,
  weekly,
  monthly;

  String get apiValue => name;

  String get label => switch (this) {
        EventRepeat.none => 'Does not repeat',
        EventRepeat.daily => 'Daily',
        EventRepeat.weekly => 'Rest of week',
        EventRepeat.monthly => 'Rest of month',
      };

  static EventRepeat fromString(String? value) {
    return EventRepeat.values.firstWhere(
      (repeat) => repeat.name == value,
      orElse: () => EventRepeat.none,
    );
  }
}

/// Calendar Event data model.
class EventModel {
  final int id;
  final int userId;
  final int? projectId;
  final String title;
  final String? description;
  final String? location;
  final String color;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? reminderAt;
  final bool allDay;
  final EventRepeat repeat;
  final int repeatInterval;
  final List<int> repeatWeekdays;
  final DateTime? recurrenceEnd;
  final List<String> skippedOccurrences;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventModel({
    required this.id,
    required this.userId,
    this.projectId,
    required this.title,
    this.description,
    this.location,
    required this.color,
    required this.startTime,
    required this.endTime,
    this.reminderAt,
    required this.allDay,
    this.repeat = EventRepeat.none,
    this.repeatInterval = 1,
    this.repeatWeekdays = const [],
    this.recurrenceEnd,
    this.skippedOccurrences = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
        id: jsonInt(json['id']),
        userId: jsonInt(json['user_id']),
        projectId: jsonNullableInt(json['project_id']),
        title: json['title'] as String? ?? 'Untitled event',
        description: json['description'] as String?,
        location: json['location'] as String?,
        color: json['color'] as String? ?? '#435f92',
        startTime: jsonDateTime(json['start_time']),
        endTime: jsonDateTime(json['end_time']),
        reminderAt: jsonNullableDateTime(json['reminder_at']),
        allDay: json['all_day'] as bool? ?? false,
        repeat: EventRepeat.fromString(json['repeat'] as String?),
        repeatInterval: jsonInt(json['repeat_interval'], fallback: 1),
        repeatWeekdays: jsonIntList(json['repeat_weekdays']),
        recurrenceEnd: jsonNullableDateTime(json['recurrence_end']),
        skippedOccurrences: jsonStringList(json['skipped_occurrences']),
        createdAt: jsonDateTime(json['created_at']),
        updatedAt: jsonDateTime(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'project_id': projectId,
        'title': title,
        'description': description,
        'location': location,
        'color': color,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'reminder_at': reminderAt?.toIso8601String(),
        'all_day': allDay,
        'repeat': repeat.apiValue,
        'repeat_interval': repeatInterval,
        'repeat_weekdays': repeatWeekdays,
        'recurrence_end': recurrenceEnd?.toIso8601String(),
        'skipped_occurrences': skippedOccurrences,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  EventModel copyWith({
    int? id,
    int? userId,
    int? projectId,
    String? title,
    String? description,
    String? location,
    String? color,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? reminderAt,
    bool? allDay,
    EventRepeat? repeat,
    int? repeatInterval,
    List<int>? repeatWeekdays,
    DateTime? recurrenceEnd,
    List<String>? skippedOccurrences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      color: color ?? this.color,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      reminderAt: reminderAt ?? this.reminderAt,
      allDay: allDay ?? this.allDay,
      repeat: repeat ?? this.repeat,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      recurrenceEnd: recurrenceEnd ?? this.recurrenceEnd,
      skippedOccurrences: skippedOccurrences ?? this.skippedOccurrences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
