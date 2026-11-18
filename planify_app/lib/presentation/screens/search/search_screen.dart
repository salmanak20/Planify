import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/theme/app_theme.dart';
import 'package:planify_app/providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'task':
        return Icons.check_circle_outline_rounded;
      case 'note':
        return Icons.article_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'project':
        return Icons.folder_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'task':
        return AppTheme.primary;
      case 'note':
        return AppTheme.tertiary;
      case 'event':
        return AppTheme.secondary;
      case 'project':
        return AppTheme.primary;
      default:
        return AppTheme.onSurfaceVariant;
    }
  }

  Widget _buildSection(String title, List<SearchItemModel> items) {
    if (items.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurfaceVariant,
                ),
          ),
        ),
        ...items.map((item) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getColorForType(item.type).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIconForType(item.type),
                    color: _getColorForType(item.type), size: 20),
              ),
              title: Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: item.subtitle != null
                  ? Text(item.subtitle!,
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              onTap: () {
                // Navigation logic could go here based on item type
              },
            )),
        const Divider(height: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLow,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppTheme.surfaceContainerLow,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search tasks, notes, events...',
            border: InputBorder.none,
          ),
          onChanged: (text) => ref.read(searchProvider.notifier).search(text),
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchCtrl.clear();
                ref.read(searchProvider.notifier).search('');
              },
            )
        ],
      ),
      body: searchAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Type to start searching...'));
          }
          if (data.isEmpty) {
            return Center(
              child: Text(
                'No results found for "${_searchCtrl.text}"',
                style: const TextStyle(color: AppTheme.onSurfaceVariant),
              ),
            );
          }
          return ListView(
            children: [
              _buildSection('Projects', data.projects),
              _buildSection('Tasks', data.tasks),
              _buildSection('Events', data.events),
              _buildSection('Notes', data.notes),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
