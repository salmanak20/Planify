import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/utils/firebase_identity.dart';
import 'package:planify_app/providers/account_scope_provider.dart';
import 'package:planify_app/providers/account_scoped_notifier.dart';

class SearchItemModel {
  final int id;
  final String type; // task, note, event, project
  final String title;
  final String? subtitle;
  final int? projectId;

  SearchItemModel({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.projectId,
  });

  factory SearchItemModel.fromJson(Map<String, dynamic> json) =>
      SearchItemModel(
        id: json['id'],
        type: json['type'],
        title: json['title'],
        subtitle: json['subtitle'],
        projectId: json['project_id'],
      );
}

class GlobalSearchResponseModel {
  final List<SearchItemModel> tasks;
  final List<SearchItemModel> notes;
  final List<SearchItemModel> events;
  final List<SearchItemModel> projects;

  GlobalSearchResponseModel({
    this.tasks = const [],
    this.notes = const [],
    this.events = const [],
    this.projects = const [],
  });

  factory GlobalSearchResponseModel.fromJson(Map<String, dynamic> json) {
    return GlobalSearchResponseModel(
      tasks: (json['tasks'] as List?)
              ?.map((e) => SearchItemModel.fromJson(e))
              .toList() ??
          [],
      notes: (json['notes'] as List?)
              ?.map((e) => SearchItemModel.fromJson(e))
              .toList() ??
          [],
      events: (json['events'] as List?)
              ?.map((e) => SearchItemModel.fromJson(e))
              .toList() ??
          [],
      projects: (json['projects'] as List?)
              ?.map((e) => SearchItemModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  bool get isEmpty =>
      tasks.isEmpty && notes.isEmpty && events.isEmpty && projects.isEmpty;
}

class SearchNotifier
    extends AccountScopedStateNotifier<AsyncValue<GlobalSearchResponseModel?>> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String? _accountUid;
  String _lastQuery = '';

  SearchNotifier(this._accountUid) : super(const AsyncData(null));

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncData(null);
      return;
    }
    _lastQuery = query;
    state = const AsyncLoading();
    try {
      final q = query.toLowerCase();
      final uid = _accountUid;
      if (uid == null) {
        state = const AsyncData(null);
        return;
      }
      requireActiveFirebaseUid(_auth, uid);
      final snapshots = await Future.wait([
        ownedQuery(_firestore, 'tasks', uid).get(),
        ownedQuery(_firestore, 'notes', uid).get(),
        ownedQuery(_firestore, 'events', uid).get(),
        ownedQuery(_firestore, 'projects', uid).get(),
      ]);
      final tasksSnap = snapshots[0];
      final notesSnap = snapshots[1];
      final eventsSnap = snapshots[2];
      final projectsSnap = snapshots[3];

      if (!mounted || _lastQuery != query || currentFirebaseUid(_auth) != uid) {
        return;
      }

      final tasks = tasksSnap.docs
          .where((doc) =>
              (doc.data()['title'] as String).toLowerCase().contains(q))
          .map((doc) => SearchItemModel(
              id: doc.data()['id'], type: 'task', title: doc.data()['title']))
          .toList();

      final notes = notesSnap.docs
          .where((doc) =>
              (doc.data()['title'] as String).toLowerCase().contains(q))
          .map((doc) => SearchItemModel(
              id: doc.data()['id'], type: 'note', title: doc.data()['title']))
          .toList();

      final events = eventsSnap.docs
          .where((doc) =>
              (doc.data()['title'] as String).toLowerCase().contains(q))
          .map((doc) => SearchItemModel(
              id: doc.data()['id'], type: 'event', title: doc.data()['title']))
          .toList();

      final projects = projectsSnap.docs
          .where(
              (doc) => (doc.data()['name'] as String).toLowerCase().contains(q))
          .map((doc) => SearchItemModel(
              id: doc.data()['id'], type: 'project', title: doc.data()['name']))
          .toList();

      state = AsyncData(GlobalSearchResponseModel(
        tasks: tasks,
        notes: notes,
        events: events,
        projects: projects,
      ));
    } catch (e, st) {
      if (_lastQuery == query &&
          _accountUid != null &&
          currentFirebaseUid(_auth) == _accountUid &&
          mounted) {
        state = AsyncError(Exception('Search could not be completed.'), st);
      }
    }
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier,
    AsyncValue<GlobalSearchResponseModel?>>(
  (ref) => SearchNotifier(ref.watch(activeAccountUidProvider)),
);
