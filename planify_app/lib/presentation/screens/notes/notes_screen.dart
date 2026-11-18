import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:planify_app/core/theme/app_theme.dart';
import 'package:planify_app/core/utils/app_snackbar.dart';
import 'package:planify_app/data/models/note_model.dart';
import 'package:planify_app/data/models/project_model.dart';
import 'package:planify_app/providers/note_categories_provider.dart';
import 'package:planify_app/providers/notes_provider.dart';
import 'package:planify_app/providers/projects_provider.dart';
import 'package:planify_app/providers/tasks_provider.dart';
import 'package:planify_app/data/repositories/notes_repository.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchCtrl = TextEditingController();

  static const _noteColors = <String>[
    '#ffffff',
    '#dae7ca',
    '#a5c1fb',
    '#fdcb9c',
    '#fa746f',
  ];

  String _search = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _trackNoteAction(Future<void> action, String failureMessage) {
    unawaited(action.catchError((_) {
      showPlanifySnackBar(failureMessage);
    }));
  }

  void _deleteNote(int id) {
    _trackNoteAction(
      ref.read(notesProvider.notifier).delete(id),
      'Could not delete note',
    );
    showPlanifySnackBar('Note deleted');
  }

  Future<String?> _showCategoryNameDialog({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Category name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryManager(List<String> categories) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Add category'),
              onTap: () async {
                final name = await _showCategoryNameDialog(
                  title: 'Add category',
                );
                if (!mounted) return;
                if (name != null && name.isNotEmpty) {
                  await ref.read(noteCategoriesProvider.notifier).create(name);
                  showPlanifySnackBar('Category added');
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            if (categories.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                child:
                    Text('No categories yet. Add one to organize your notes.'),
              )
            else
              ...categories.map(
                (category) => ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(category),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final renamed = await _showCategoryNameDialog(
                            title: 'Rename category',
                            initialValue: category,
                          );
                          if (renamed != null && renamed.isNotEmpty) {
                            await ref
                                .read(noteCategoriesProvider.notifier)
                                .rename(category, renamed);
                            if (_selectedCategory == category) {
                              setState(() => _selectedCategory = renamed);
                            }
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.error,
                        ),
                        onPressed: () async {
                          await ref
                              .read(noteCategoriesProvider.notifier)
                              .delete(category);
                          if (_selectedCategory == category) {
                            setState(() => _selectedCategory = null);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNoteEditor({NoteModel? note}) async {
    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final contentCtrl = TextEditingController(text: note?.content ?? '');
    final tagsCtrl = TextEditingController(text: note?.tags.join(', ') ?? '');
    final projects =
        ref.read(projectsProvider).valueOrNull ?? const <ProjectModel>[];
    final categories =
        ref.read(noteCategoriesProvider).valueOrNull ?? const <String>[];
    var selectedColor = note?.color ?? _noteColors.first;
    var selectedCategory = note?.folder;
    int? selectedProjectId = note?.projectId;

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note == null ? 'New Note' : 'Edit Note',
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
                  decoration: const InputDecoration(hintText: 'Note title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Start writing...',
                  ),
                  contextMenuBuilder: (context, editableTextState) {
                    final List<ContextMenuButtonItem> buttonItems =
                        editableTextState.contextMenuButtonItems;
                    if (note != null &&
                        contentCtrl.selection.isValid &&
                        !contentCtrl.selection.isCollapsed) {
                      buttonItems.add(ContextMenuButtonItem(
                        onPressed: () {
                          ContextMenuController.removeAny();
                          final selectedText = contentCtrl.selection
                              .textInside(contentCtrl.text);
                          _convertNoteLineToTask(note, selectedText);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        label: 'Create Task',
                      ));
                    }
                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: editableTextState.contextMenuAnchors,
                      buttonItems: buttonItems,
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    hintText: 'Category',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No category'),
                    ),
                    ...categories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category,
                        child: Text(category),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setSheetState(() => selectedCategory = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagsCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Tags (comma separated)',
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
                  children: _noteColors.map((color) {
                    final swatch = _colorFromHex(
                      color,
                      AppTheme.surfaceContainerLowest,
                    );
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
                                ? AppTheme.primary
                                : AppTheme.outlineVariant,
                            width: selectedColor == color ? 2.5 : 1,
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
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      final content = contentCtrl.text.trim();
                      final tags = tagsCtrl.text
                          .split(',')
                          .map((tag) => tag.trim())
                          .where((tag) => tag.isNotEmpty)
                          .toList();

                      if (selectedCategory != null &&
                          selectedCategory!.trim().isNotEmpty) {
                        await ref
                            .read(noteCategoriesProvider.notifier)
                            .create(selectedCategory!);
                      }

                      if (note == null) {
                        _trackNoteAction(
                          ref.read(notesProvider.notifier).create(
                                title: title,
                                content: content.isEmpty ? null : content,
                                color: selectedColor,
                                folder: selectedCategory,
                                tags: tags,
                                projectId: selectedProjectId,
                              ),
                          'Could not create note',
                        );
                        showPlanifySnackBar('Note created');
                      } else {
                        _trackNoteAction(
                          ref.read(notesProvider.notifier).update(
                            note.id,
                            {
                              'title': title,
                              'content': content.isEmpty ? null : content,
                              'color': selectedColor,
                              'folder': selectedCategory,
                              'tags': tags,
                              'project_id': selectedProjectId,
                            },
                          ),
                          'Could not update note',
                        );
                        showPlanifySnackBar('Note updated');
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      note == null ? 'Save Note' : 'Update Note',
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
      ),
    );
  }

  Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final normalized = hex.replaceAll('#', '');
    if (normalized.length != 6) return fallback;
    return Color(int.parse('FF$normalized', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    final categoriesAsync = ref.watch(noteCategoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLow,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteEditor(),
        backgroundColor: AppTheme.secondaryContainer,
        foregroundColor: AppTheme.onSecondaryContainer,
        child: const Icon(Icons.edit_rounded),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppTheme.surfaceContainerLow.withAlpha(204),
            elevation: 0,
            title: Text(
              'Notes',
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.category_outlined),
                onPressed: () => _showCategoryManager(
                  categoriesAsync.valueOrNull ?? const <String>[],
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (value) {
                    setState(() => _search = value.toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    fillColor: AppTheme.surfaceContainerHigh,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            sliver: notesAsync.when(
              data: (notes) {
                var filtered = notes;
                if (_search.isNotEmpty) {
                  filtered = filtered
                      .where(
                        (note) =>
                            note.title.toLowerCase().contains(_search) ||
                            (note.content?.toLowerCase().contains(_search) ??
                                false),
                      )
                      .toList();
                }
                if (_selectedCategory != null) {
                  filtered = filtered
                      .where((note) => note.folder == _selectedCategory)
                      .toList();
                }

                final pinned = filtered.where((note) => note.isPinned).toList();
                final unpinned =
                    filtered.where((note) => !note.isPinned).toList();

                return SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _CategoriesRow(
                        categories:
                            categoriesAsync.valueOrNull ?? const <String>[],
                        selected: _selectedCategory,
                        onSelect: (category) {
                          setState(() {
                            _selectedCategory =
                                category == _selectedCategory ? null : category;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (pinned.isNotEmpty) ...[
                        const _SectionLabel(label: 'PINNED'),
                        const SizedBox(height: 8),
                        _NotesGrid(
                          notes: pinned,
                          onOpen: (note) => _showNoteEditor(note: note),
                          onPin: (id) =>
                              ref.read(notesProvider.notifier).togglePin(id),
                          onDelete: _deleteNote,
                          onConvertToTask: (note) => _convertNoteToTask(note),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (unpinned.isNotEmpty) ...[
                        if (pinned.isNotEmpty)
                          const _SectionLabel(label: 'OTHERS'),
                        if (pinned.isNotEmpty) const SizedBox(height: 8),
                        _NotesGrid(
                          notes: unpinned,
                          onOpen: (note) => _showNoteEditor(note: note),
                          onPin: (id) =>
                              ref.read(notesProvider.notifier).togglePin(id),
                          onDelete: _deleteNote,
                          onConvertToTask: (note) => _convertNoteToTask(note),
                        ),
                      ],
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 64),
                          child: Center(
                            child: Text('No notes yet. Tap + to create one.'),
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error: $error')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _convertNoteToTask(NoteModel note) async {
    try {
      await ref.read(notesRepositoryProvider).convertToTask(
            note.id,
            lineText: note.title,
            projectId: note.projectId,
          );
      await ref.read(tasksProvider.notifier).load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created from note')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not convert note to task')),
      );
    }
  }

  Future<void> _convertNoteLineToTask(NoteModel note, String lineText) async {
    try {
      await ref.read(notesRepositoryProvider).convertToTask(
            note.id,
            lineText: lineText,
            projectId: note.projectId,
          );
      await ref.read(tasksProvider.notifier).load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created from selected text')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not convert text to task')),
      );
    }
  }
}

class _CategoriesRow extends StatelessWidget {
  const _CategoriesRow({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = selected == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.secondaryContainer
                      : AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 14,
                      color: isSelected
                          ? AppTheme.onSecondaryContainer
                          : AppTheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isSelected
                                ? AppTheme.onSecondaryContainer
                                : AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
    );
  }
}

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({
    required this.notes,
    required this.onOpen,
    required this.onPin,
    required this.onDelete,
    required this.onConvertToTask,
  });

  final List<NoteModel> notes;
  final ValueChanged<NoteModel> onOpen;
  final ValueChanged<int> onPin;
  final ValueChanged<int> onDelete;
  final ValueChanged<NoteModel> onConvertToTask;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.94,
      ),
      itemCount: notes.length,
      itemBuilder: (_, index) => _NoteGridCard(
        note: notes[index],
        onOpen: onOpen,
        onPin: onPin,
        onDelete: onDelete,
        onConvertToTask: onConvertToTask,
      ),
    );
  }
}

class _NoteGridCard extends StatelessWidget {
  const _NoteGridCard({
    required this.note,
    required this.onOpen,
    required this.onPin,
    required this.onDelete,
    required this.onConvertToTask,
  });

  final NoteModel note;
  final ValueChanged<NoteModel> onOpen;
  final ValueChanged<int> onPin;
  final ValueChanged<int> onDelete;
  final ValueChanged<NoteModel> onConvertToTask;

  Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final normalized = hex.replaceAll('#', '');
    if (normalized.length != 6) return fallback;
    return Color(int.parse('FF$normalized', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final background =
        _colorFromHex(note.color, AppTheme.surfaceContainerLowest);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onOpen(note),
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Open & edit'),
                    onTap: () {
                      Navigator.pop(context);
                      onOpen(note);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.push_pin_outlined),
                    title: Text(note.isPinned ? 'Unpin' : 'Pin'),
                    onTap: () {
                      Navigator.pop(context);
                      onPin(note.id);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.checklist_rounded),
                    title: const Text('Convert to task'),
                    onTap: () {
                      Navigator.pop(context);
                      onConvertToTask(note);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.error,
                    ),
                    title: const Text(
                      'Delete',
                      style: TextStyle(color: AppTheme.error),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onDelete(note.id);
                    },
                  ),
                ],
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (note.isPinned)
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: AppTheme.secondary,
                      ),
                    const Spacer(),
                    if (note.folder != null && note.folder!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(18),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          note.folder!,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                ),
                const SizedBox(height: 6),
                if (note.content != null && note.content!.isNotEmpty)
                  Text(
                    note.content!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                const Spacer(),
                if (note.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      note.tags.take(2).join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                Text(
                  DateFormat('MMM d').format(note.updatedAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
