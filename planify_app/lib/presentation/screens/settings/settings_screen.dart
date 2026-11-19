import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:planify_app/core/services/notifications_service.dart';
import 'package:planify_app/core/theme/app_theme.dart';
import 'package:planify_app/data/datasources/local_cache_service.dart';
import 'package:planify_app/providers/account_scope_provider.dart';
import 'package:planify_app/providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.surfaceContainerLow,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        children: [
          _buildSectionHeader('Appearance'),
          const SizedBox(height: 16),
          Card(
            color: AppTheme.surfaceContainerLowest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _buildThemeTile(
                  context: context,
                  title: 'System Theme',
                  icon: Icons.brightness_auto_rounded,
                  isSelected: themeMode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.system),
                ),
                const Divider(),
                _buildThemeTile(
                  context: context,
                  title: 'Light Theme',
                  icon: Icons.light_mode_rounded,
                  isSelected: themeMode == ThemeMode.light,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.light),
                ),
                const Divider(),
                _buildThemeTile(
                  context: context,
                  title: 'Dark Theme',
                  icon: Icons.dark_mode_rounded,
                  isSelected: themeMode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Notifications'),
          const SizedBox(height: 16),
          Card(
            color: AppTheme.surfaceContainerLowest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppTheme.onPrimaryContainer,
                ),
              ),
              title: const Text(
                'Request Permissions',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Enable notifications and exact reminder alarms.',
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await NotificationsService.instance.requestPermissions();
                final uid = ref.read(activeAccountUidProvider);
                if (uid != null) {
                  await NotificationsService.instance.restoreCachedReminders(
                    uid: uid,
                    cache: ref.read(localCacheServiceProvider),
                  );
                }
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Permissions requested.')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppTheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildThemeTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppTheme.primary : AppTheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
