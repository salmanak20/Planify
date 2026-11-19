class UserCacheKey {
  const UserCacheKey._(this.uid, this.value);

  final String uid;
  final String value;
}

enum DemoCacheKey {
  tasks('demo_tasks_cache'),
  notes('demo_notes_cache'),
  events('demo_events_cache'),
  projects('demo_projects_cache'),
  reminders('demo_reminders_cache');

  const DemoCacheKey(this.value);

  final String value;
}

abstract final class CacheKeys {
  static UserCacheKey tasks(String uid) => _userKey('tasks_cache', uid);
  static UserCacheKey notes(String uid) => _userKey('notes_cache', uid);
  static UserCacheKey events(String uid) => _userKey('events_cache', uid);
  static UserCacheKey projects(String uid) => _userKey('projects_cache', uid);
  static UserCacheKey reminders(String uid) => _userKey('reminders_cache', uid);
  static UserCacheKey profile(String uid) => _userKey('auth_user', uid);
  static UserCacheKey noteCategories(String uid) =>
      _userKey('note_categories_cache', uid);

  static List<UserCacheKey> forUser(String uid) => [
        tasks(uid),
        notes(uid),
        events(uid),
        projects(uid),
        reminders(uid),
        profile(uid),
        noteCategories(uid),
      ];

  static const legacyAccountSpecificKeys = <String>[
    'tasks_cache',
    'notes_cache',
    'events_cache',
    'projects_cache',
    'reminders_cache',
    'auth_user',
    'note_categories_cache',
  ];

  static UserCacheKey _userKey(String prefix, String uid) {
    if (uid.isEmpty || uid.trim() != uid || uid.length > 128) {
      throw ArgumentError.value(
          uid, 'uid', 'A valid Firebase UID is required.');
    }
    if (uid.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
      throw ArgumentError.value(uid, 'uid', 'UID contains invalid characters.');
    }
    // Firebase UIDs are opaque. Encode path separators and other reserved
    // characters while retaining the familiar raw UID for ordinary values.
    final safeUid = Uri.encodeComponent(uid);
    return UserCacheKey._(uid, '${prefix}_$safeUid');
  }
}
