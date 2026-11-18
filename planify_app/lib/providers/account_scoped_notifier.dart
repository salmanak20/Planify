import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ignores completions from async work after a UID change disposed the old
/// provider, instead of allowing a stale notifier to throw or publish state.
abstract class AccountScopedStateNotifier<State> extends StateNotifier<State> {
  AccountScopedStateNotifier(super.initialState);

  @override
  set state(State value) {
    if (!mounted) return;
    super.state = value;
  }
}
