import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/constants/app_flags.dart';
import 'package:planify_app/core/utils/firebase_identity.dart';
import 'package:planify_app/data/datasources/cache_keys.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/data/mock/demo_data.dart';
import 'package:planify_app/data/models/reminder_model.dart';

class RemindersRepository {
  final LocalCacheService _cache;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  RemindersRepository(this._cache);

  String? get _uid => _auth.currentUser?.uid;
  int get _userId => currentStableUserId(_auth) ?? 0;

  Future<List<ReminderModel>> getReminders({bool? isCompleted}) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      return _applyFilters(await _readOrSeedCache(), isCompleted: isCompleted);
    }

    try {
      Query query = ownedQuery(_firestore, 'reminders', _uid!);
      final snapshot = await query.get();
      final reminders = snapshot.docs
          .map((doc) =>
              ReminderModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      await _writeCache(reminders);
      return _applyFilters(reminders, isCompleted: isCompleted);
    } catch (_) {
      final cached = await _readCache();
      if (cached.isNotEmpty) {
        return _applyFilters(cached, isCompleted: isCompleted);
      }
      rethrow;
    }
  }

  List<ReminderModel> _applyFilters(
    List<ReminderModel> reminders, {
    bool? isCompleted,
  }) {
    var filtered = [...reminders];
    if (isCompleted != null) {
      filtered = filtered.where((r) => r.isCompleted == isCompleted).toList();
    }
    filtered.sort((a, b) => a.reminderTime.compareTo(b.reminderTime));
    return filtered;
  }

  Future<ReminderModel> createReminder({
    required String title,
    String? notes,
    required DateTime reminderTime,
    ReminderRepeat repeat = ReminderRepeat.none,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now();
    final reminder = ReminderModel(
      id: id,
      userId: _userId == 0 ? demoUser.id : _userId,
      title: title,
      notes: notes,
      reminderTime: reminderTime,
      isCompleted: false,
      repeat: repeat,
      createdAt: now,
      updatedAt: now,
    );

    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache([reminder, ...cached.where((item) => item.id != id)]);
      return reminder;
    }

    await _firestore
        .collection('reminders')
        .doc(id.toString())
        .set(withFirebaseOwner(reminder.toJson(), _uid!));

    final cached = await _readCache();
    await _writeCache([reminder, ...cached.where((item) => item.id != id)]);
    return reminder;
  }

  Future<ReminderModel> updateReminder(
      int id, Map<String, dynamic> updates) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      final updated = _applyUpdate(cached, id, updates);
      await _writeCache(_replaceReminder(cached, updated));
      return updated;
    }

    updates['updated_at'] = DateTime.now().toIso8601String();
    updates['firebase_uid'] = _uid!;
    await _firestore.collection('reminders').doc(id.toString()).update(updates);
    final doc =
        await _firestore.collection('reminders').doc(id.toString()).get();
    final reminder = ReminderModel.fromJson(doc.data()!);

    final cached = await _readCache();
    await _writeCache(_replaceReminder(cached, reminder));
    return reminder;
  }

  Future<ReminderModel> toggleComplete(int id) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      final index = cached.indexWhere((reminder) => reminder.id == id);
      if (index == -1) throw Exception('Reminder $id not found');
      final toggled = cached[index].copyWith(
        isCompleted: !cached[index].isCompleted,
        updatedAt: DateTime.now(),
      );
      await _writeCache(_replaceReminder(cached, toggled));
      return toggled;
    }

    final docRef = _firestore.collection('reminders').doc(id.toString());
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Reminder $id not found');
    final current = ReminderModel.fromJson(doc.data()!);
    final toggled = current.copyWith(
      isCompleted: !current.isCompleted,
      updatedAt: DateTime.now(),
    );
    await docRef.update(withFirebaseOwner(toggled.toJson(), _uid!));

    final cached = await _readCache();
    await _writeCache(_replaceReminder(cached, toggled));
    return toggled;
  }

  Future<void> deleteReminder(int id) async {
    if (kEnableOfflineTestingMode || _uid == null) {
      final cached = await _readOrSeedCache();
      await _writeCache(
        cached.where((reminder) => reminder.id != id).toList(),
      );
      return;
    }

    await _firestore.collection('reminders').doc(id.toString()).delete();

    final cached = await _readCache();
    await _writeCache(
      cached.where((reminder) => reminder.id != id).toList(),
    );
  }

  Future<List<ReminderModel>> _readCache() async {
    final cached = await _cache.readJsonList(remindersCacheKey);
    return cached.map(ReminderModel.fromJson).toList();
  }

  Future<List<ReminderModel>> _readOrSeedCache() async {
    final cached = await _readCache();
    if (cached.isNotEmpty) return cached;
    final seed = buildDemoReminders();
    await _writeCache(seed);
    return seed;
  }

  Future<void> _writeCache(List<ReminderModel> reminders) {
    return _cache.saveJsonList(
      remindersCacheKey,
      reminders.map((reminder) => reminder.toJson()).toList(),
    );
  }

  ReminderModel _applyUpdate(
    List<ReminderModel> reminders,
    int id,
    Map<String, dynamic> updates,
  ) {
    final index = reminders.indexWhere((reminder) => reminder.id == id);
    if (index == -1) throw Exception('Reminder $id not found');
    final data = Map<String, dynamic>.from(reminders[index].toJson())
      ..addAll(updates)
      ..['updated_at'] = DateTime.now().toIso8601String();
    return ReminderModel.fromJson(data);
  }

  List<ReminderModel> _replaceReminder(
    List<ReminderModel> reminders,
    ReminderModel reminder,
  ) {
    return [
      reminder,
      ...reminders.where((item) => item.id != reminder.id),
    ];
  }
}

final remindersRepositoryProvider = Provider<RemindersRepository>(
  (ref) => RemindersRepository(
    ref.watch(localCacheServiceProvider),
  ),
);
