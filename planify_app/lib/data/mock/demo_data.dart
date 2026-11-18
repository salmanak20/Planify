import 'package:planify_app/data/models/event_model.dart';
import 'package:planify_app/data/models/insights_model.dart';
import 'package:planify_app/data/models/note_model.dart';
import 'package:planify_app/data/models/project_model.dart';
import 'package:planify_app/data/models/reminder_model.dart';
import 'package:planify_app/data/models/task_model.dart';
import 'package:planify_app/data/models/user_model.dart';

const demoUser = UserModel(
  id: 1,
  email: 'tester@planify.app',
  fullName: 'Planify Tester',
  avatarColor: '#435f92',
);

DateTime _todayAt(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

List<ProjectModel> buildDemoProjects() {
  final now = DateTime.now();
  return [
    ProjectModel(
      id: 11,
      userId: demoUser.id,
      name: 'Launch Sprint',
      description: 'Polish the onboarding, notifications, and calendar flow.',
      color: '#435f92',
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now.subtract(const Duration(hours: 3)),
    ),
    ProjectModel(
      id: 12,
      userId: demoUser.id,
      name: 'Content Studio',
      description: 'Notes and assets for the upcoming campaign.',
      color: '#57634c',
      createdAt: now.subtract(const Duration(days: 8)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
    ProjectModel(
      id: 13,
      userId: demoUser.id,
      name: 'Personal Ops',
      description: 'Recurring admin and weekly planning.',
      color: '#7c5831',
      createdAt: now.subtract(const Duration(days: 6)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
  ];
}

List<TaskModel> buildDemoTasks() {
  final now = DateTime.now();
  return [
    TaskModel(
      id: 101,
      userId: demoUser.id,
      projectId: 11,
      title: 'Finalize release checklist',
      description:
          'Review QA items and confirm the smoke-test path for Android.',
      priority: TaskPriority.high,
      isComplete: false,
      tags: const ['release', 'qa'],
      deadline: _todayAt(10, 30),
      reminderAt: _todayAt(10, 0),
      subtasks: const [
        SubtaskModel(id: 1001, title: 'Verify auth bypass', isComplete: true),
        SubtaskModel(
            id: 1002, title: 'Check task creation flow', isComplete: false),
      ],
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
    ),
    TaskModel(
      id: 102,
      userId: demoUser.id,
      projectId: 12,
      title: 'Draft weekly content notes',
      description: 'Summarize campaign ideas and attach rough talking points.',
      priority: TaskPriority.medium,
      isComplete: false,
      tags: const ['content'],
      deadline: _todayAt(15, 0),
      reminderAt: _todayAt(14, 0),
      subtasks: const [],
      createdAt: now.subtract(const Duration(days: 1, hours: 5)),
      updatedAt: now.subtract(const Duration(hours: 5)),
    ),
    TaskModel(
      id: 103,
      userId: demoUser.id,
      projectId: 13,
      title: 'Reset inbox to zero',
      description: 'Clear follow-ups before end of day.',
      priority: TaskPriority.low,
      isComplete: true,
      tags: const ['admin'],
      deadline: now.subtract(const Duration(days: 1)),
      reminderAt: null,
      subtasks: const [],
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(hours: 20)),
    ),
    TaskModel(
      id: 104,
      userId: demoUser.id,
      projectId: null,
      title: 'Plan tomorrow focus block',
      description: 'Choose one deep-work target for the morning.',
      priority: TaskPriority.medium,
      isComplete: false,
      tags: const ['planning'],
      deadline: _todayAt(18, 30),
      reminderAt: _todayAt(18, 0),
      subtasks: const [],
      createdAt: now.subtract(const Duration(hours: 10)),
      updatedAt: now.subtract(const Duration(hours: 1)),
    ),
  ];
}

List<NoteModel> buildDemoNotes() {
  final now = DateTime.now();
  return [
    NoteModel(
      id: 201,
      userId: demoUser.id,
      projectId: 12,
      title: 'Campaign hooks',
      content:
          'Lead with the calm-planning angle, then show the daily workflow.',
      color: '#fdcb9c',
      isPinned: true,
      folder: 'Marketing',
      tags: const ['copy', 'launch'],
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 3)),
    ),
    NoteModel(
      id: 202,
      userId: demoUser.id,
      projectId: 11,
      title: 'Release retro ideas',
      content:
          'Capture friction points from setup, notifications, and dashboard load.',
      color: '#dae7ca',
      isPinned: false,
      folder: 'Product',
      tags: const ['retro'],
      createdAt: now.subtract(const Duration(days: 4)),
      updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
    ),
    NoteModel(
      id: 203,
      userId: demoUser.id,
      projectId: null,
      title: 'Quick wins',
      content:
          'Add a tester banner, improve empty states, polish project chip colors.',
      color: '#a5c1fb',
      isPinned: false,
      folder: 'Scratchpad',
      tags: const ['ideas'],
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(hours: 6)),
    ),
  ];
}

List<EventModel> buildDemoEvents() {
  final now = DateTime.now();
  final todayStandupStart = _todayAt(11, 0);
  final todayStandupEnd = _todayAt(11, 30);
  final deepWorkStart = _todayAt(16, 0);
  final deepWorkEnd = _todayAt(17, 30);
  final nextDay = now.add(const Duration(days: 1));
  final reviewStart = DateTime(nextDay.year, nextDay.month, nextDay.day, 9, 30);
  final reviewEnd = DateTime(nextDay.year, nextDay.month, nextDay.day, 10, 15);

  return [
    EventModel(
      id: 301,
      userId: demoUser.id,
      projectId: 11,
      title: 'Launch standup',
      description: 'Daily sync with the product team.',
      location: 'War room',
      color: '#435f92',
      startTime: todayStandupStart,
      endTime: todayStandupEnd,
      reminderAt: todayStandupStart.subtract(const Duration(minutes: 30)),
      allDay: false,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
    ),
    EventModel(
      id: 302,
      userId: demoUser.id,
      projectId: 12,
      title: 'Deep work block',
      description: 'Write and refine the first draft.',
      location: 'Studio',
      color: '#57634c',
      startTime: deepWorkStart,
      endTime: deepWorkEnd,
      reminderAt: deepWorkStart.subtract(const Duration(hours: 1)),
      allDay: false,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(hours: 4)),
    ),
    EventModel(
      id: 303,
      userId: demoUser.id,
      projectId: 13,
      title: 'Weekly review',
      description: 'Check what shipped and what rolls into next week.',
      location: null,
      color: '#7c5831',
      startTime: reviewStart,
      endTime: reviewEnd,
      reminderAt: reviewStart.subtract(const Duration(minutes: 30)),
      allDay: false,
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
  ];
}

List<ReminderModel> buildDemoReminders() {
  final now = DateTime.now();
  return [
    ReminderModel(
      id: 401,
      userId: demoUser.id,
      title: 'Take vitamins',
      notes: 'Morning supplement stack',
      reminderTime: _todayAt(8, 0),
      isCompleted: true,
      repeat: ReminderRepeat.daily,
      createdAt: now.subtract(const Duration(days: 7)),
      updatedAt: now.subtract(const Duration(hours: 2)),
    ),
    ReminderModel(
      id: 402,
      userId: demoUser.id,
      title: 'Submit timesheet',
      notes: null,
      reminderTime: _todayAt(17, 0),
      isCompleted: false,
      repeat: ReminderRepeat.weekly,
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
    ReminderModel(
      id: 403,
      userId: demoUser.id,
      title: 'Water the plants',
      notes: 'All indoor plants including the fern',
      reminderTime: _todayAt(19, 30),
      isCompleted: false,
      repeat: ReminderRepeat.none,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(hours: 6)),
    ),
    ReminderModel(
      id: 404,
      userId: demoUser.id,
      title: 'Pay rent',
      notes: 'Transfer via bank app',
      reminderTime: DateTime(now.year, now.month + 1, 1, 9, 0),
      isCompleted: false,
      repeat: ReminderRepeat.monthly,
      createdAt: now.subtract(const Duration(days: 14)),
      updatedAt: now.subtract(const Duration(days: 3)),
    ),
  ];
}

bool _sameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _matchesQuery(String query, String? text) {
  if (text == null || text.isEmpty) return false;
  return text.toLowerCase().contains(query);
}

/// Dashboard API payload synthesized from other demo fixtures.
DashboardSummaryModel buildDemoDashboardSummary() {
  final now = DateTime.now();
  final tasks = buildDemoTasks();

  var todayTasks = tasks
      .where(
        (t) =>
            !t.isComplete &&
            t.deadline != null &&
            _sameCalendarDay(t.deadline!, now),
      )
      .map(
        (t) => DashboardTaskItemModel(
          id: t.id,
          title: t.title,
          deadline: t.deadline,
          priority: t.priority.apiValue,
          isComplete: t.isComplete,
        ),
      )
      .toList();

  if (todayTasks.isEmpty) {
    todayTasks = tasks
        .where((t) => !t.isComplete)
        .take(4)
        .map(
          (t) => DashboardTaskItemModel(
            id: t.id,
            title: t.title,
            deadline: t.deadline,
            priority: t.priority.apiValue,
            isComplete: t.isComplete,
          ),
        )
        .toList();
  }

  final upcomingEvents = buildDemoEvents()
      .where(
        (e) => !e.endTime.isBefore(now.subtract(const Duration(minutes: 1))),
      )
      .toList();
  upcomingEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

  final recentNotes = [...buildDemoNotes()];
  recentNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  return DashboardSummaryModel(
    todayTasks: todayTasks,
    upcomingEvents: upcomingEvents
        .map(
          (e) => DashboardEventItemModel(
            id: e.id,
            title: e.title,
            startTime: e.startTime,
            endTime: e.endTime,
            allDay: e.allDay,
          ),
        )
        .toList(),
    activeFocusSession: null,
    recentNotes: recentNotes
        .map(
          (n) => DashboardNoteItemModel(
            id: n.id,
            title: n.title,
            updatedAt: n.updatedAt,
            isPinned: n.isPinned,
          ),
        )
        .toList(),
  );
}

/// Client-side search over demo content (mirrors `/search` groups).
SearchGroupModel buildDemoSearchResults(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return const SearchGroupModel(
      tasks: [],
      notes: [],
      events: [],
      projects: [],
    );
  }

  final tasks = buildDemoTasks()
      .where(
        (t) =>
            _matchesQuery(q, t.title) ||
            _matchesQuery(q, t.description) ||
            t.tags.any((tag) => _matchesQuery(q, tag)),
      )
      .map(
        (t) => SearchItemModel(
          id: t.id,
          type: 'task',
          title: t.title,
          subtitle: t.description,
          projectId: t.projectId,
        ),
      )
      .toList();

  final notes = buildDemoNotes()
      .where(
        (n) =>
            _matchesQuery(q, n.title) ||
            _matchesQuery(q, n.content) ||
            n.tags.any((tag) => _matchesQuery(q, tag)),
      )
      .map(
        (n) => SearchItemModel(
          id: n.id,
          type: 'note',
          title: n.title,
          subtitle: n.folder,
          projectId: n.projectId,
        ),
      )
      .toList();

  final events = buildDemoEvents()
      .where(
        (e) =>
            _matchesQuery(q, e.title) ||
            _matchesQuery(q, e.description) ||
            _matchesQuery(q, e.location),
      )
      .map(
        (e) => SearchItemModel(
          id: e.id,
          type: 'event',
          title: e.title,
          subtitle: e.description,
          projectId: e.projectId,
        ),
      )
      .toList();

  final projects = buildDemoProjects()
      .where(
        (p) => _matchesQuery(q, p.name) || _matchesQuery(q, p.description),
      )
      .map(
        (p) => SearchItemModel(
          id: p.id,
          type: 'project',
          title: p.name,
          subtitle: p.description,
          projectId: p.id,
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

ProjectAnalyticsModel buildDemoProjectAnalytics(int projectId) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final tasks =
      buildDemoTasks().where((t) => t.projectId == projectId).toList();
  final completed = tasks.where((t) => t.isComplete).length;
  final total = tasks.length;
  final progressPercent = total == 0 ? 0.0 : (completed / total) * 100.0;
  final overdueItems = tasks
      .where(
        (t) =>
            !t.isComplete &&
            t.deadline != null &&
            t.deadline!.isBefore(startOfToday),
      )
      .length;

  final activity = <ProjectActivityModel>[];
  for (final t in tasks) {
    activity.add(
      ProjectActivityModel(
        itemType: 'task',
        itemId: t.id,
        title: t.title,
        timestamp: t.updatedAt,
      ),
    );
  }
  for (final n in buildDemoNotes().where((n) => n.projectId == projectId)) {
    activity.add(
      ProjectActivityModel(
        itemType: 'note',
        itemId: n.id,
        title: n.title,
        timestamp: n.updatedAt,
      ),
    );
  }
  activity.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return ProjectAnalyticsModel(
    projectId: projectId,
    progressPercent: progressPercent,
    completedTasks: completed,
    overdueItems: overdueItems,
    recentActivity: activity.take(8).toList(),
  );
}
