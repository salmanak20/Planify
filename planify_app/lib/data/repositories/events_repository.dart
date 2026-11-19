import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/constants/app_flags.dart';
import 'package:planify_app/core/utils/firebase_identity.dart';
import 'package:planify_app/data/datasources/cache_keys.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/data/mock/demo_data.dart';
import 'package:planify_app/data/models/event_model.dart';
import 'package:planify_app/providers/account_scope_provider.dart';

class EventsRepository {
  final LocalCacheService _cache;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String? _uid;
  final CacheSession? _session;

  EventsRepository(this._cache, this._uid)
      : _session = _uid == null ? null : _cache.captureSession(_uid);

  int get _userId => currentStableUserId(_auth) ?? 0;

  Future<List<EventModel>> getEvents({DateTime? start, DateTime? end}) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      return _applyRange(await _readOrSeedCache(), start: start, end: end);
    }

    try {
      _requireActiveUid();
      Query query = ownedQuery(_firestore, 'events', _uid);
      final snapshot = await query.get();
      _requireActiveUid();
      final events = snapshot.docs
          .map((doc) => EventModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      await _writeCache(events);
      return _applyRange(events, start: start, end: end);
    } catch (_) {
      _requireActiveUid();
      final cached = await _readCache();
      if (cached.isNotEmpty) {
        return _applyRange(cached, start: start, end: end);
      }
      rethrow;
    }
  }

  List<EventModel> _applyRange(
    List<EventModel> events, {
    DateTime? start,
    DateTime? end,
  }) {
    var filtered = [...events];
    if (start != null) {
      filtered = filtered
          .where((event) =>
              event.endTime.isAfter(start) ||
              event.endTime.isAtSameMomentAs(start))
          .toList();
    }
    if (end != null) {
      filtered = filtered
          .where((event) =>
              event.startTime.isBefore(end) ||
              event.startTime.isAtSameMomentAs(end))
          .toList();
    }
    filtered.sort((a, b) => a.startTime.compareTo(b.startTime));

    return filtered;
  }

  Future<EventModel> createEvent({
    required String title,
    String? description,
    String? location,
    String color = '#435f92',
    int? projectId,
    required DateTime startTime,
    required DateTime endTime,
    DateTime? reminderAt,
    bool allDay = false,
    EventRepeat repeat = EventRepeat.none,
    int repeatInterval = 1,
    List<int> repeatWeekdays = const [],
    DateTime? recurrenceEnd,
    List<String> skippedOccurrences = const [],
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now();
    final event = EventModel(
      id: id,
      userId: _userId == 0 ? demoUser.id : _userId,
      projectId: projectId,
      title: title,
      description: description,
      location: location,
      color: color,
      startTime: startTime,
      endTime: endTime,
      reminderAt: reminderAt,
      allDay: allDay,
      repeat: repeat,
      repeatInterval: repeatInterval,
      repeatWeekdays: repeatWeekdays,
      recurrenceEnd: recurrenceEnd,
      skippedOccurrences: skippedOccurrences,
      createdAt: now,
      updatedAt: now,
    );

    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache([event, ...cached.where((item) => item.id != id)]);
      return event;
    }

    _requireActiveUid();
    await _firestore
        .collection('events')
        .doc(id.toString())
        .set(withFirebaseOwner(event.toJson(), _uid));

    _requireActiveUid();
    final cached = await _readCache();
    await _writeCache([event, ...cached.where((item) => item.id != id)]);
    return event;
  }

  Future<EventModel> updateEvent(int id, Map<String, dynamic> updates) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      final updated = _applyUpdate(cached, id, updates);
      await _writeCache(_replaceEvent(cached, updated));
      return updated;
    }

    updates['updated_at'] = DateTime.now().toIso8601String();
    updates['firebase_uid'] = _uid;
    _requireActiveUid();
    await _firestore.collection('events').doc(id.toString()).update(updates);
    _requireActiveUid();
    final doc = await _firestore.collection('events').doc(id.toString()).get();
    _requireActiveUid();
    final event = EventModel.fromJson(doc.data()!);

    final cached = await _readCache();
    await _writeCache(_replaceEvent(cached, event));
    return event;
  }

  Future<void> deleteEvent(int id) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache(cached.where((event) => event.id != id).toList());
      return;
    }

    _requireActiveUid();
    await _firestore.collection('events').doc(id.toString()).delete();
    _requireActiveUid();

    final cached = await _readCache();
    await _writeCache(cached.where((event) => event.id != id).toList());
  }

  Future<List<EventModel>> _readCache() async {
    if (_uid == null || kEnableOfflineTestingMode) {
      return (await _cache.readDemoJsonList(DemoCacheKey.events))
          .map(EventModel.fromJson)
          .toList();
    }
    final cached = await _cache.readJsonListForUser(
      _session!,
      CacheKeys.events(_uid),
    );
    return cached.map(EventModel.fromJson).toList();
  }

  String _requireActiveUid() {
    final uid = requireActiveFirebaseUid(_auth, _uid);
    _cache.ensureSessionCurrent(_session!);
    return uid;
  }

  Future<List<EventModel>> _readOrSeedCache() async {
    final cached = await _readCache();
    if (cached.isNotEmpty) return cached;
    final seed = buildDemoEvents();
    await _writeCache(seed);
    return seed;
  }

  Future<void> _writeCache(List<EventModel> events) {
    final values = events.map((event) => event.toJson()).toList();
    if (_uid == null || kEnableOfflineTestingMode) {
      return _cache.saveDemoJsonList(DemoCacheKey.events, values);
    }
    return _cache.saveJsonListForUser(
        _session!, CacheKeys.events(_uid), values);
  }

  EventModel _applyUpdate(
    List<EventModel> events,
    int id,
    Map<String, dynamic> updates,
  ) {
    final index = events.indexWhere((event) => event.id == id);
    if (index == -1) throw Exception('Event $id not found');
    final data = Map<String, dynamic>.from(events[index].toJson())
      ..addAll(updates)
      ..['updated_at'] = DateTime.now().toIso8601String();
    return EventModel.fromJson(data);
  }

  List<EventModel> _replaceEvent(List<EventModel> events, EventModel event) {
    return [
      event,
      ...events.where((item) => item.id != event.id),
    ];
  }
}

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(
    ref.watch(localCacheServiceProvider),
    ref.watch(activeAccountUidProvider),
  ),
);
