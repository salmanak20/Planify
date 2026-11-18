import 'package:cloud_firestore/cloud_firestore.dart';

int jsonInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? jsonNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime jsonDateTime(dynamic value, {DateTime? fallback}) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return fallback ?? DateTime.now();
}

DateTime? jsonNullableDateTime(dynamic value) {
  if (value == null) return null;
  return jsonDateTime(value);
}

List<String> jsonStringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .where((item) => item != null)
      .map((item) => item.toString())
      .toList();
}

List<int> jsonIntList(dynamic value) {
  if (value is! List) return const [];
  return value.map(jsonInt).toList();
}
