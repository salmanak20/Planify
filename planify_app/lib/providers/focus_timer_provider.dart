import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planify_app/core/constants/app_flags.dart';
import 'package:planify_app/core/services/audio_service.dart';
import 'package:planify_app/core/utils/firebase_identity.dart';
import 'package:planify_app/data/models/task_model.dart';
import 'package:planify_app/providers/account_scope_provider.dart';

enum TimerPhase { focus, shortBreak, longBreak }

class FocusTimerState {
  final TimerPhase phase;
  final Duration total;
  final Duration remaining;
  final bool isRunning;
  final int sessionsCompleted;
  final TaskModel? currentTask;
  final DateTime? sessionEndsAt;
  final String? selectedAmbientSound; // 'rain', 'whitenoise', 'woods', 'fire'

  const FocusTimerState({
    this.phase = TimerPhase.focus,
    this.total = const Duration(minutes: 25),
    this.remaining = const Duration(minutes: 25),
    this.isRunning = false,
    this.sessionsCompleted = 0,
    this.currentTask,
    this.sessionEndsAt,
    this.selectedAmbientSound,
  });

  double get progress => 1 - (remaining.inSeconds / total.inSeconds);

  String get displayTime {
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  FocusTimerState copyWith({
    TimerPhase? phase,
    Duration? total,
    Duration? remaining,
    bool? isRunning,
    int? sessionsCompleted,
    TaskModel? currentTask,
    bool clearTask = false,
    DateTime? sessionEndsAt,
    bool clearSessionEndsAt = false,
    String? selectedAmbientSound,
    bool clearSound = false,
  }) =>
      FocusTimerState(
        phase: phase ?? this.phase,
        total: total ?? this.total,
        remaining: remaining ?? this.remaining,
        isRunning: isRunning ?? this.isRunning,
        sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
        currentTask: clearTask ? null : currentTask ?? this.currentTask,
        sessionEndsAt:
            clearSessionEndsAt ? null : sessionEndsAt ?? this.sessionEndsAt,
        selectedAmbientSound: clearSound
            ? null
            : selectedAmbientSound ?? this.selectedAmbientSound,
      );
}

class FocusTimerNotifier extends StateNotifier<FocusTimerState> {
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _accountUid;
  String? _focusSessionUid;

  FocusTimerNotifier([this._accountUid]) : super(const FocusTimerState()) {
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void setAccountUid(String? uid) {
    if (_accountUid == uid) return;
    _accountUid = uid;
    _focusSessionUid = null;
    _timer?.cancel();
    _timer = null;
    _audioPlayer.stop();
    state = const FocusTimerState();
  }

  static const _phaseDurations = {
    TimerPhase.focus: Duration(minutes: 25),
    TimerPhase.shortBreak: Duration(minutes: 5),
    TimerPhase.longBreak: Duration(minutes: 15),
  };

  void start() {
    if (state.isRunning) return;
    _focusSessionUid = state.phase == TimerPhase.focus ? _accountUid : null;
    SystemSound.play(SystemSoundType.click);
    state = state.copyWith(
      isRunning: true,
      sessionEndsAt: DateTime.now().add(state.remaining),
    );
    unawaited(_playAmbientSound());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    _timer?.cancel();
    SystemSound.play(SystemSoundType.click);
    state = state.copyWith(
      isRunning: false,
      remaining: _remainingFromNow(),
      clearSessionEndsAt: true,
    );
    _audioPlayer.pause();
  }

  void reset() {
    _timer?.cancel();
    final total = _phaseDurations[state.phase]!;
    SystemSound.play(SystemSoundType.click);
    state = state.copyWith(
      isRunning: false,
      total: total,
      remaining: total,
      clearSessionEndsAt: true,
    );
    _audioPlayer.stop();
  }

  void skip() {
    _timer?.cancel();
    SystemSound.play(SystemSoundType.click);
    _audioPlayer.stop();
    _nextPhase();
  }

  void selectPhase(TimerPhase phase) {
    _timer?.cancel();
    final total = _phaseDurations[phase]!;
    SystemSound.play(SystemSoundType.click);
    state = state.copyWith(
      phase: phase,
      total: total,
      remaining: total,
      isRunning: false,
      clearSessionEndsAt: true,
    );
    _audioPlayer.stop();
  }

  void setTask(TaskModel? task) {
    state = task == null
        ? state.copyWith(clearTask: true)
        : state.copyWith(currentTask: task);
  }

  void selectAmbientSound(String? sound) async {
    SystemSound.play(
      sound == state.selectedAmbientSound
          ? SystemSoundType.click
          : SystemSoundType.alert,
    );

    if (sound == state.selectedAmbientSound) {
      state = state.copyWith(clearSound: true);
      await _audioPlayer.stop();
    } else {
      state = state.copyWith(selectedAmbientSound: sound);
      await _playAmbientSound();
    }
  }

  Future<void> _playAmbientSound() async {
    final selectedSound = state.selectedAmbientSound;
    if (selectedSound == null) return;

    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource('sounds/ambient/$selectedSound.wav'));
  }

  void _tick() {
    final remaining = _remainingFromNow();
    if (remaining.inSeconds <= 0) {
      _finishCurrentPhase();
      return;
    }

    state = state.copyWith(remaining: remaining);
  }

  void _nextPhase() {
    TimerPhase next;
    int sessions = state.sessionsCompleted;

    if (state.phase == TimerPhase.focus) {
      if (state.remaining.inSeconds <= 5) {
        // If naturally finished, log it
        _logSession(_phaseDurations[TimerPhase.focus]!, _focusSessionUid);
      }
      _focusSessionUid = null;
      sessions++;
      next = sessions % 4 == 0 ? TimerPhase.longBreak : TimerPhase.shortBreak;
    } else {
      next = TimerPhase.focus;
    }

    final total = _phaseDurations[next]!;
    audioService.playTimerDone();
    state = state.copyWith(
      phase: next,
      total: total,
      remaining: total,
      isRunning: false,
      sessionsCompleted: sessions,
      clearSessionEndsAt: true,
    );
  }

  void syncWithClock() {
    if (!state.isRunning) return;

    final remaining = _remainingFromNow();
    if (remaining.inSeconds <= 0) {
      _finishCurrentPhase();
      return;
    }

    state = state.copyWith(remaining: remaining);
  }

  void _finishCurrentPhase() {
    _timer?.cancel();
    _audioPlayer.stop();
    state = state.copyWith(remaining: Duration.zero);
    _nextPhase();
  }

  Duration _remainingFromNow() {
    final endsAt = state.sessionEndsAt;
    if (endsAt == null) {
      return state.remaining;
    }

    final diff = endsAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Future<void> _logSession(Duration duration, String? ownerUid) async {
    if (kEnableOfflineTestingMode || ownerUid == null) return;
    try {
      requireActiveFirebaseUid(FirebaseAuth.instance, ownerUid);
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection('focus_sessions').add({
        'firebase_uid': ownerUid,
        'user_id': stableUserIdFromUid(ownerUid),
        'project_id': state.currentTask?.projectId,
        'task_id': state.currentTask?.id,
        'start_time': now.subtract(duration).toIso8601String(),
        'end_time': now.toIso8601String(),
        'duration_seconds': duration.inSeconds,
      });
      requireActiveFirebaseUid(FirebaseAuth.instance, ownerUid);
    } catch (_) {
      // Ignore if offline
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

final focusTimerProvider =
    StateNotifierProvider<FocusTimerNotifier, FocusTimerState>(
  (ref) {
    final notifier = FocusTimerNotifier(ref.read(activeAccountUidProvider));
    ref.listen<String?>(activeAccountUidProvider, (_, uid) {
      notifier.setAccountUid(uid);
    });
    return notifier;
  },
);
