import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:planify_app/core/services/notifications_service.dart';
import 'package:planify_app/core/theme/app_theme.dart';
import 'package:planify_app/data/models/task_model.dart';
import 'package:planify_app/providers/focus_timer_provider.dart';
import 'package:planify_app/providers/tasks_provider.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with WidgetsBindingObserver {
  bool _backgroundNotificationsArmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(NotificationsService.instance.cancelFocusNotifications());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(focusTimerProvider.notifier);
    final timer = ref.read(focusTimerProvider);

    if (state == AppLifecycleState.resumed) {
      notifier.syncWithClock();
      _clearBackgroundNotifications();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _armBackgroundNotifications(timer);
    }
  }

  void _armBackgroundNotifications(FocusTimerState timer) {
    if (_backgroundNotificationsArmed ||
        !timer.isRunning ||
        timer.sessionEndsAt == null) {
      return;
    }

    _backgroundNotificationsArmed = true;
    unawaited(
      NotificationsService.instance.showFocusBackgroundStatus(
        remaining: timer.remaining,
        taskTitle: timer.currentTask?.title,
      ),
    );
    unawaited(
      NotificationsService.instance.scheduleFocusSessionCompletion(
        completesAt: timer.sessionEndsAt!,
        taskTitle: timer.currentTask?.title,
      ),
    );
  }

  void _clearBackgroundNotifications() {
    _backgroundNotificationsArmed = false;
    unawaited(NotificationsService.instance.cancelFocusNotifications());
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(focusTimerProvider);
    final notifier = ref.read(focusTimerProvider.notifier);
    final tasks = ref.watch(tasksProvider).valueOrNull ?? const <TaskModel>[];
    final pendingTasks = tasks.where((task) => !task.isComplete).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, __) {
        if (didPop) return;
        notifier.pause();
        _clearBackgroundNotifications();
        context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: AppTheme.focusBg1,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.focusBg1, AppTheme.focusBg2],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primary.withAlpha(40),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Planify',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white70,
                            ),
                          ),
                          const Spacer(),
                          ...TimerPhase.values.map(
                            (phase) => GestureDetector(
                              onTap: () => notifier.selectPhase(phase),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: timer.phase == phase
                                        ? Colors.white12
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: timer.phase == phase
                                          ? Colors.white30
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Text(
                                    _phaseLabel(phase),
                                    style: TextStyle(
                                      color: timer.phase == phase
                                          ? Colors.white
                                          : Colors.white38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          const Text(
                            'CURRENTLY FOCUSING ON',
                            style: TextStyle(
                              color: AppTheme.primaryFixedDim,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: pendingTasks.isEmpty
                                ? null
                                : () => _showTaskPicker(context, pendingTasks),
                            child: Text(
                              timer.currentTask?.title ??
                                  'Tap to select a task',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (timer.currentTask != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color:
                                      AppTheme.primaryContainer.withAlpha(60),
                                ),
                              ),
                              child: Text(
                                timer.currentTask!.priority.label.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.primaryFixedDim,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CustomPaint(
                              painter: _RingPainter(progress: timer.progress),
                            ),
                          ),
                          Text(
                            timer.displayTime,
                            style: GoogleFonts.manrope(
                              fontSize: 72,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ControlBtn(
                          icon: Icons.replay_rounded,
                          onTap: () {
                            notifier.reset();
                            _clearBackgroundNotifications();
                          },
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () {
                            if (timer.isRunning) {
                              notifier.pause();
                              _clearBackgroundNotifications();
                            } else {
                              notifier.start();
                            }
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withAlpha(80),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              timer.isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppTheme.primaryDim,
                              size: 44,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        _ControlBtn(
                          icon: Icons.skip_next_rounded,
                          onTap: () {
                            notifier.skip();
                            _clearBackgroundNotifications();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Session ${timer.sessionsCompleted + 1}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Row(
                        children: [
                          Text(
                            'Ambient Preview',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Row(
                        children: [
                          Text(
                            timer.selectedAmbientSound == null
                                ? 'Tap a sound card to preview it.'
                                : 'Selected: ${timer.selectedAmbientSound}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Row(
                        children: [
                          _AmbientCard(
                            id: 'rain',
                            icon: Icons.thunderstorm_outlined,
                            label: 'Rain',
                            selected: timer.selectedAmbientSound == 'rain',
                            onTap: notifier.selectAmbientSound,
                          ),
                          const SizedBox(width: 8),
                          _AmbientCard(
                            id: 'whitenoise',
                            icon: Icons.waves_rounded,
                            label: 'Noise',
                            selected:
                                timer.selectedAmbientSound == 'whitenoise',
                            onTap: notifier.selectAmbientSound,
                          ),
                          const SizedBox(width: 8),
                          _AmbientCard(
                            id: 'woods',
                            icon: Icons.forest_outlined,
                            label: 'Forest',
                            selected: timer.selectedAmbientSound == 'woods',
                            onTap: notifier.selectAmbientSound,
                          ),
                          const SizedBox(width: 8),
                          _AmbientCard(
                            id: 'fire',
                            icon: Icons.local_fire_department_outlined,
                            label: 'Fire',
                            selected: timer.selectedAmbientSound == 'fire',
                            onTap: notifier.selectAmbientSound,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: TextButton.icon(
                        onPressed: () {
                          notifier.pause();
                          _clearBackgroundNotifications();
                          context.pop();
                        },
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: AppTheme.errorContainer,
                        ),
                        label: Text(
                          'Leave Focus',
                          style: GoogleFonts.manrope(
                            color: AppTheme.errorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _phaseLabel(TimerPhase phase) => switch (phase) {
        TimerPhase.focus => 'Focus',
        TimerPhase.shortBreak => 'Short',
        TimerPhase.longBreak => 'Long',
      };

  void _showTaskPicker(
    BuildContext context,
    List<TaskModel> tasks,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F21),
      builder: (_) => ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (_, index) => ListTile(
          title: Text(
            tasks[index].title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: () {
            ref.read(focusTimerProvider.notifier).setTask(tasks[index]);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _AmbientCard extends StatelessWidget {
  const _AmbientCard({
    required this.id,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<String?> onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryContainer.withAlpha(60)
                : Colors.white10,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryContainer.withAlpha(100)
                  : Colors.white12,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? AppTheme.primaryFixedDim : Colors.white54,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.primaryFixedDim : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 3.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withAlpha(15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = AppTheme.primaryContainer
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
