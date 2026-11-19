import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:planify_app/core/utils/firebase_identity.dart';
import 'package:planify_app/data/models/insights_model.dart';
import 'package:planify_app/data/models/task_model.dart';
import 'package:planify_app/data/models/note_model.dart';

class InsightsRepository {
  static const _configuredApiBaseUrl =
      String.fromEnvironment('PLANIFY_API_BASE_URL');
  static const _smartInsightUnavailable =
      'Smart insights are unavailable right now. Try again later.';

  InsightsRepository({
    String apiBaseUrl = _configuredApiBaseUrl,
    http.Client Function()? httpClientFactory,
    Future<String?> Function()? idTokenProvider,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _apiBaseUrl = apiBaseUrl,
        _httpClientFactory = httpClientFactory ?? (() => http.Client()),
        _idTokenProvider = idTokenProvider,
        _authOverride = auth,
        _firestoreOverride = firestore;

  final String _apiBaseUrl;
  final http.Client Function() _httpClientFactory;
  final Future<String?> Function()? _idTokenProvider;
  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Future<DashboardSummaryModel> getDashboardSummary() async {
    final uid = _requireUid();
    final snapshots = await Future.wait([
      ownedQuery(_firestore, 'tasks', uid).limit(5).get(),
      ownedQuery(_firestore, 'events', uid).limit(5).get(),
      ownedQuery(_firestore, 'notes', uid).limit(5).get(),
    ]);
    _requireSameUid(uid);
    final tasksSnap = snapshots[0];
    final eventsSnap = snapshots[1];
    final notesSnap = snapshots[2];

    final todayTasks = tasksSnap.docs
        .map((doc) => DashboardTaskItemModel.fromJson(doc.data()))
        .toList();
    final upcomingEvents = eventsSnap.docs
        .map((doc) => DashboardEventItemModel.fromJson(doc.data()))
        .toList();
    final recentNotes = notesSnap.docs
        .map((doc) => DashboardNoteItemModel.fromJson(doc.data()))
        .toList();

    return DashboardSummaryModel(
      todayTasks: todayTasks,
      upcomingEvents: upcomingEvents,
      recentNotes: recentNotes,
    );
  }

  Future<ProjectAnalyticsModel> getProjectAnalytics(int projectId) async {
    final uid = _requireUid();
    final tasksSnap = await ownedQuery(
      _firestore,
      'tasks',
      uid,
    ).where('project_id', isEqualTo: projectId).get();
    _requireSameUid(uid);

    int completed = 0;
    for (var doc in tasksSnap.docs) {
      if (doc.data()['is_complete'] == true) {
        completed++;
      }
    }

    return ProjectAnalyticsModel(
      projectId: projectId,
      progressPercent:
          tasksSnap.docs.isEmpty ? 0 : completed / tasksSnap.docs.length,
      completedTasks: completed,
      overdueItems: 0,
      recentActivity: [],
    );
  }

  Future<SearchGroupModel> searchAll(String query) async {
    final q = query.toLowerCase();
    final uid = _requireUid();

    final snapshots = await Future.wait([
      ownedQuery(_firestore, 'tasks', uid).get(),
      ownedQuery(_firestore, 'notes', uid).get(),
      ownedQuery(_firestore, 'events', uid).get(),
      ownedQuery(_firestore, 'projects', uid).get(),
    ]);
    _requireSameUid(uid);
    final tasksSnap = snapshots[0];
    final notesSnap = snapshots[1];
    final eventsSnap = snapshots[2];
    final projectsSnap = snapshots[3];

    final tasks = tasksSnap.docs
        .where(
          (doc) => (doc.data()['title'] as String).toLowerCase().contains(q),
        )
        .map(
          (doc) => SearchItemModel(
            id: doc.data()['id'],
            type: 'task',
            title: doc.data()['title'],
          ),
        )
        .toList();

    final notes = notesSnap.docs
        .where(
          (doc) => (doc.data()['title'] as String).toLowerCase().contains(q),
        )
        .map(
          (doc) => SearchItemModel(
            id: doc.data()['id'],
            type: 'note',
            title: doc.data()['title'],
          ),
        )
        .toList();

    final events = eventsSnap.docs
        .where(
          (doc) => (doc.data()['title'] as String).toLowerCase().contains(q),
        )
        .map(
          (doc) => SearchItemModel(
            id: doc.data()['id'],
            type: 'event',
            title: doc.data()['title'],
          ),
        )
        .toList();

    final projects = projectsSnap.docs
        .where(
          (doc) => (doc.data()['name'] as String).toLowerCase().contains(q),
        )
        .map(
          (doc) => SearchItemModel(
            id: doc.data()['id'],
            type: 'project',
            title: doc.data()['name'],
          ),
        )
        .toList();

    return SearchGroupModel(
      tasks: tasks,
      notes: notes,
      events: events,
      projects: projects,
    );
  }

  Future<String> generateSmartInsight(
    List<TaskModel> tasks,
    List<NoteModel> notes,
  ) async {
    try {
      if (_apiBaseUrl.trim().isEmpty) {
        return _smartInsightUnavailable;
      }

      final baseUri = Uri.tryParse(_apiBaseUrl.trim());
      if (baseUri == null ||
          !baseUri.hasAuthority ||
          !{'http', 'https'}.contains(baseUri.scheme)) {
        return _smartInsightUnavailable;
      }

      final tokenProvider = _idTokenProvider;
      final user = tokenProvider == null ? _auth.currentUser : null;
      final requestUid = user?.uid;
      if (tokenProvider == null && user == null) {
        return _smartInsightUnavailable;
      }
      final idToken = tokenProvider != null
          ? await tokenProvider()
          : await user!.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        return _smartInsightUnavailable;
      }
      // Auth may change while Firebase is fetching a fresh token. Never send
      // Account A's token after Account B has become the active session.
      if (tokenProvider == null &&
          (_auth.currentUser == null || _auth.currentUser!.uid != requestUid)) {
        return _smartInsightUnavailable;
      }

      final endpoint = baseUri.replace(
        path: '${baseUri.path.replaceFirst(RegExp(r'/$'), '')}/insights/smart',
        query: null,
        fragment: null,
      );
      final client = _httpClientFactory();
      try {
        final response = await client
            .post(
              endpoint,
              headers: {
                'Authorization': 'Bearer $idToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'tasks': tasks.take(5).map((task) => task.title).toList(),
                'notes': notes.take(5).map((note) => note.title).toList(),
              }),
            )
            .timeout(const Duration(seconds: 25));

        if (tokenProvider == null &&
            (_auth.currentUser == null ||
                _auth.currentUser!.uid != requestUid)) {
          return _smartInsightUnavailable;
        }

        if (response.statusCode != 200) {
          return _smartInsightUnavailable;
        }
        final body = jsonDecode(response.body);
        if (body is! Map<String, dynamic> || body['insight'] is! String) {
          return _smartInsightUnavailable;
        }
        final insight = (body['insight'] as String).trim();
        return insight.isEmpty ? _smartInsightUnavailable : insight;
      } finally {
        client.close();
      }
    } catch (_) {
      return _smartInsightUnavailable;
    }
  }

  String _requireUid() {
    return requireActiveFirebaseUid(_auth, _uid);
  }

  void _requireSameUid(String expectedUid) {
    requireActiveFirebaseUid(_auth, expectedUid);
  }
}

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => InsightsRepository(),
);
