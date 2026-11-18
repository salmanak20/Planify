import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized');
});

class ThemeSettings {
  final ThemeMode themeMode;
  final bool hasCompletedOnboarding;

  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.hasCompletedOnboarding = false,
  });

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    bool? hasCompletedOnboarding,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

class SettingsNotifier extends StateNotifier<ThemeSettings> {
  final SharedPreferences prefs;

  SettingsNotifier(this.prefs) : super(const ThemeSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    final modeStr = prefs.getString('themeMode') ?? 'system';
    final mode = ThemeMode.values.firstWhere(
      (m) => m.name == modeStr,
      orElse: () => ThemeMode.system,
    );
    final hasOnboarded = prefs.getBool('hasCompletedOnboarding') ?? false;

    state =
        ThemeSettings(themeMode: mode, hasCompletedOnboarding: hasOnboarded);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await prefs.setString('themeMode', mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> completeOnboarding() async {
    await prefs.setBool('hasCompletedOnboarding', true);
    state = state.copyWith(hasCompletedOnboarding: true);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, ThemeSettings>((ref) {
  return SettingsNotifier(ref.watch(sharedPreferencesProvider));
});
