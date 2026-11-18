import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:planify_app/core/theme/app_theme.dart';
import 'package:planify_app/core/utils/app_snackbar.dart';
import 'package:planify_app/data/models/project_model.dart';
import 'package:planify_app/data/models/task_model.dart';
import 'package:planify_app/providers/projects_provider.dart';
import 'package:planify_app/providers/tasks_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _searchCtrl = TextEditingController();

  static const _projectColors = <String>[
    '#435f92',
    '#57634c',
    '#7c5831',
    '#a83836',
    '#1f2224',
  ];

  String _search = '';
  TaskPriority? _filterPriority;
  bool? _filterComplete;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _trackTaskAction(Future<void> action, String failureMessage) {
    unawaited(action.catchError((_) {
      showPlanifySnackBar(failureMessage);
    }));
  }

  Future<void> _deleteTask(TaskModel task) {
    _trackTaskAction(
      ref.read(tasksProvider.notifier).delete(task.id),
      'Could not delete task',
    );
    showPlanifySnackBar('Task deleted');
    return Future<void>.value();
  }

  Future<void> _showTaskSheet({TaskModel? task}) async {
    final titleCtrl = TextEditingController(text: task?.title ?? '');
    final descCtrl = TextEditingController(text: task?.description ?? '');
    final tagsCtrl = TextEditingController(text: task?.tags.join(', ') ?? '');
    final projects =
        ref.read(projectsProvider).valueOrNull ?? const <ProjectModel>[];
    var priority = task?.priority ?? TaskPriority.medium;
    var deadline = task?.deadline;
    var reminderAt = task?.reminderAt;
    int? selectedProjectId = task?.projectId;
    final subtaskCtrls = (task?.subtasks ?? const <SubtaskModel>[])
        .map((subtask) => TextEditingController(text: subtask.title))
        .toList();
    final subtaskStates = (task?.subtasks ?? const <SubtaskModel>[])
        .map((subtask) => subtask)
        .toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final deadlineLabel = deadline == null
              ? 'Set deadline'
              : DateFormat('MMM d, h:mm a').format(deadline!);
          final actionLabel = task == null ? 'Add Task' : 'Update Task';

          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task == null ? 'New Task' : 'Edit Task',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Task title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Description (optional)',
                    ),
                  ),
                  if (projects.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedProjectId,
                      decoration: const InputDecoration(
                        hintText: 'Attach to project',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No project'),
                        ),
                        ...projects.map(
                          (project) => DropdownMenuItem<int?>(
                            value: project.id,
                            child: Text(project.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setSheetState(() => selectedProjectId = value);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Tags (comma separated)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Priority',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TaskPriority.values.map((value) {
                      final selected = priority == value;
                      return ChoiceChip(
                        label: Text(value.label),
                        selected: selected,
                        onSelected: (_) {
                          setSheetState(() => priority = value);
                        },
                        selectedColor: _priorityColor(value).withAlpha(38),
                        labelStyle: TextStyle(
                          color: selected
                              ? _priorityColor(value)
                              : AppTheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: ctx,
                              initialDate: deadline ?? DateTime.now(),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (pickedDate == null || !ctx.mounted) return;
                            final pickedTime = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(
                                deadline ??
                                    DateTime.now()
                                        .add(const Duration(hours: 1)),
                              ),
                            );
                            if (pickedTime == null) return;
                            setSheetState(() {
                              deadline = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                              if (reminderAt != null &&
                                  reminderAt!.isAfter(deadline!)) {
                                reminderAt = deadline!.subtract(
                                  const Duration(minutes: 30),
                                );
                              }
                            });
                          },
                          icon: const Icon(Icons.event_outlined, size: 16),
                          label: Text(deadlineLabel),
                        ),
                      ),
                      if (deadline != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              deadline = null;
                              reminderAt = null;
                            });
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('No reminder'),
                        selected: reminderAt == null,
                        onSelected: (_) {
                          setSheetState(() => reminderAt = null);
                        },
                      ),
                      FilterChip(
                        label: const Text('30 min before'),
                        selected: deadline != null &&
                            reminderAt ==
                                deadline!.subtract(const Duration(minutes: 30)),
                        onSelected: deadline == null
                            ? null
                            : (_) {
                                setSheetState(() {
                                  reminderAt = deadline!.subtract(
                                    const Duration(minutes: 30),
                                  );
                                });
                              },
                      ),
                      FilterChip(
                        label: const Text('1 hour before'),
                        selected: deadline != null &&
                            reminderAt ==
                                deadline!.subtract(const Duration(hours: 1)),
                        onSelected: deadline == null
                            ? null
                            : (_) {
                                setSheetState(() {
                                  reminderAt = deadline!.subtract(
                                    const Duration(hours: 1),
                                  );
                                });
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Subtasks',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(subtaskCtrls.length, (index) {
                    return Row(
                      children: [
                        Checkbox(
                          value: subtaskStates[index].isComplete,
                          onChanged: (checked) {
                            setSheetState(() {
                              subtaskStates[index] =
                                  subtaskStates[index].copyWith(
                                isComplete: checked ?? false,
                              );
                            });
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: subtaskCtrls[index],
                            decoration: const InputDecoration(
                                hintText: 'Subtask title'),
                            onChanged: (value) {
                              setSheetState(() {
                                subtaskStates[index] =
                                    subtaskStates[index].copyWith(title: value);
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            setSheetState(() {
                              subtaskCtrls.removeAt(index);
                              subtaskStates.removeAt(index);
                            });
                          },
                        ),
                      ],
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setSheetState(() {
                          subtaskCtrls.add(TextEditingController());
                          subtaskStates.add(
                            SubtaskModel(
                              id: DateTime.now().microsecondsSinceEpoch,
                              title: '',
                              isComplete: false,
                            ),
                          );
                        });
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add subtask'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;
                        final description = descCtrl.text.trim();
                        final tags = tagsCtrl.text
                            .split(',')
                            .map((tag) => tag.trim())
                            .where((tag) => tag.isNotEmpty)
                            .toList();

                        if (task == null) {
                          _trackTaskAction(
                            ref.read(tasksProvider.notifier).create(
                                  title: title,
                                  description:
                                      description.isEmpty ? null : description,
                                  priority: priority,
                                  tags: tags,
                                  deadline: deadline,
                                  reminderAt: reminderAt,
                                  projectId: selectedProjectId,
                                ),
                            'Could not create task',
                          );
                          showPlanifySnackBar('Task created');
                        } else {
                          final cleaned = subtaskStates
                              .asMap()
                              .entries
                              .map((entry) => entry.value.copyWith(
                                    title: subtaskCtrls[entry.key].text.trim(),
                                  ))
                              .where((subtask) => subtask.title.isNotEmpty)
                              .toList();
                          _trackTaskAction(
                            ref.read(tasksProvider.notifier).update(
                              task.id,
                              {
                                'title': title,
                                'description':
                                    description.isEmpty ? null : description,
                                'priority': priority.apiValue,
                                'tags': tags,
                                'deadline': deadline?.toIso8601String(),
                                'reminder_at': reminderAt?.toIso8601String(),
                                'project_id': selectedProjectId,
                                'subtasks': cleaned
                                    .map(
                                      (subtask) => {
                                        'id': subtask.id,
                                        'title': subtask.title,
                                        'is_complete': subtask.isComplete,
                                      },
                                    )
                                    .toList(),
                              },
                            ),
                            'Could not update task',
                          );
                          showPlanifySnackBar('Task updated');
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        actionLabel,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showProjectSheet() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var selectedColor = _projectColors.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Project',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Project name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Color',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _projectColors.map((color) {
                  final swatch = _colorFromHex(color, AppTheme.primary);
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedColor = color),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == color
                              ? AppTheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final description = descCtrl.text.trim();
                    await ref.read(projectsProvider.notifier).create(
                          name: name,
                          description: description.isEmpty ? null : description,
                          color: selectedColor,
                        );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Create Project',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleTask(TaskModel task) async {
    await ref.read(tasksProvider.notifier).toggleComplete(task.id);
  }

  Color _priorityColor(TaskPriority priority) => switch (priority) {
        TaskPriority.high => AppTheme.error,
        TaskPriority.medium => AppTheme.tertiary,
        TaskPriority.low => AppTheme.secondary,
      };

  Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final normalized = hex.replaceAll('#', '');
    if (normalized.length != 6) return fallback;
    return Color(int.parse('FF$normalized', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final projectNames = {
      for (final project in projectsAsync.valueOrNull ?? const <ProjectModel>[])
        project.id: project.name,
    };

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLow,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskSheet(),
        child: const Icon(Icons.add_rounded),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppTheme.surfaceContainerLow.withAlpha(204),
            elevation: 0,
            title: Text(
              'My Workspace',
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (value) {
                      setState(() => _search = value.toLowerCase());
                    },
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      fillColor: AppTheme.surfaceContainerHigh,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filterPriority == null &&
                              _filterComplete == null,
                          onTap: () {
                            setState(() {
                              _filterPriority = null;
                              _filterComplete = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'High',
                          selected: _filterPriority == TaskPriority.high,
                          onTap: () {
                            setState(() {
                              _filterPriority =
                                  _filterPriority == TaskPriority.high
                                      ? null
                                      : TaskPriority.high;
                            });
                          },
                          color: AppTheme.errorContainer,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Medium',
                          selected: _filterPriority == TaskPriority.medium,
                          onTap: () {
                            setState(() {
                              _filterPriority =
                                  _filterPriority == TaskPriority.medium
                                      ? null
                                      : TaskPriority.medium;
                            });
                          },
                          color: AppTheme.tertiaryContainer,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Low',
                          selected: _filterPriority == TaskPriority.low,
                          onTap: () {
                            setState(() {
                              _filterPriority =
                                  _filterPriority == TaskPriority.low
                                      ? null
                                      : TaskPriority.low;
                            });
                          },
                          color: AppTheme.secondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Done',
                          selected: _filterComplete == true,
                          onTap: () {
                            setState(() {
                              _filterComplete =
                                  _filterComplete == true ? null : true;
                            });
                          },
                          color: AppTheme.surfaceContainerHigh,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  tasksAsync.whenData((tasks) {
                        final completed =
                            tasks.where((task) => task.isComplete).length;
                        final total = tasks.length;
                        final progress = total == 0 ? 0.0 : completed / total;
                        return Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryDim],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: GoogleFonts.manrope(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Tasks completed this week',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.trending_up_rounded,
                                size: 48,
                                color: Colors.white30,
                              ),
                            ],
                          ),
                        );
                      }).value ??
                      const SizedBox(),
                  tasksAsync.when(
                    data: (tasks) {
                      var filtered = tasks;
                      if (_filterPriority != null) {
                        filtered = filtered
                            .where((task) => task.priority == _filterPriority)
                            .toList();
                      }
                      if (_filterComplete != null) {
                        filtered = filtered
                            .where(
                              (task) => task.isComplete == _filterComplete,
                            )
                            .toList();
                      }
                      if (_search.isNotEmpty) {
                        filtered = filtered
                            .where(
                              (task) =>
                                  task.title.toLowerCase().contains(_search) ||
                                  (task.description
                                          ?.toLowerCase()
                                          .contains(_search) ??
                                      false),
                            )
                            .toList();
                      }

                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: Text('No tasks found')),
                        );
                      }

                      return Column(
                        children: filtered
                            .map(
                              (task) => _TaskCard(
                                task: task,
                                projectName: projectNames[task.projectId],
                                onToggle: () => _toggleTask(task),
                                onEdit: () => _showTaskSheet(task: task),
                                onDelete: () => _deleteTask(task),
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Center(child: Text('Error: $error')),
                  ),
                  const SizedBox(height: 20),
                  projectsAsync.when(
                    data: (projects) {
                      return _ProjectsPanel(
                        projects: projects,
                        onCreateProject: _showProjectSheet,
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? AppTheme.primaryContainer)
              : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    selected ? AppTheme.onSurface : AppTheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.projectName,
  });

  final TaskModel task;
  final Future<void> Function() onToggle;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;
  final String? projectName;

  Color _priorityBg(TaskPriority priority) => switch (priority) {
        TaskPriority.high => AppTheme.errorContainer,
        TaskPriority.medium => AppTheme.tertiaryContainer,
        TaskPriority.low => AppTheme.secondaryContainer,
      };

  Color _priorityFg(TaskPriority priority) => switch (priority) {
        TaskPriority.high => AppTheme.onErrorContainer,
        TaskPriority.medium => AppTheme.onTertiaryContainer,
        TaskPriority.low => AppTheme.onSecondaryContainer,
      };

  @override
  Widget build(BuildContext context) {
    final cardColor = task.isComplete
        ? AppTheme.surfaceContainerLow
        : AppTheme.surfaceContainerLowest;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: onToggle,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        task.isComplete
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: task.isComplete
                            ? AppTheme.primary
                            : AppTheme.outlineVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  decoration: task.isComplete
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.isComplete
                                      ? AppTheme.onSurfaceVariant
                                      : AppTheme.onSurface,
                                ),
                          ),
                          if (task.description != null &&
                              task.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              task.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await onEdit();
                        }
                        if (value == 'delete') {
                          await onDelete();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _priorityBg(task.priority),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        task.priority.label.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _priorityFg(task.priority),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (projectName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          projectName!,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    if (task.deadline != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 11,
                              color: AppTheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM d, h:mm a')
                                  .format(task.deadline!),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ...task.tags.take(2).map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              tag.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                  ],
                ),
                if (task.subtasks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...task.subtasks.take(3).map(
                        (subtask) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                subtask.isComplete
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 16,
                                color: subtask.isComplete
                                    ? AppTheme.secondary
                                    : AppTheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                subtask.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: subtask.isComplete
                                          ? AppTheme.onSurfaceVariant
                                          : AppTheme.onSurface,
                                      decoration: subtask.isComplete
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectsPanel extends StatelessWidget {
  const _ProjectsPanel({
    required this.projects,
    required this.onCreateProject,
  });

  final List<ProjectModel> projects;
  final Future<void> Function() onCreateProject;

  Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final normalized = hex.replaceAll('#', '');
    if (normalized.length != 6) return fallback;
    return Color(int.parse('FF$normalized', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Projects',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (projects.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('No projects yet. Create one to group tasks.'),
            ),
          ...projects.map((project) {
            final projectColor = _colorFromHex(project.color, AppTheme.primary);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: projectColor.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: projectColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      project.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: onCreateProject,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(
              'New Project',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppTheme.outlineVariant.withAlpha(100),
                style: BorderStyle.solid,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
