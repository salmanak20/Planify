import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingStorageKey = 'has_completed_onboarding';

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) {
    _loaded = _load();
  }

  late final Future<void> _loaded;

  /// Splash and other entry flows should await this so routing does not run
  /// while [state] is still the default `false` before SharedPreferences loads.
  Future<void> waitUntilLoaded() => _loaded;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_onboardingStorageKey) ?? false;
  }

  Future<void> completeOnboarding() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingStorageKey, true);
  }

  Future<void> resetOnboarding() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingStorageKey);
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, bool>(
  (ref) => OnboardingNotifier(),
);
