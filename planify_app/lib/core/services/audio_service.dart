import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playTaskComplete() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/task_complete.wav'));
  }

  Future<void> playTimerDone() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/timer_done.wav'));
  }

  Future<void> playPop() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/pop.wav'));
  }

  void dispose() {
    _player.dispose();
  }
}

final audioService = AudioService();
