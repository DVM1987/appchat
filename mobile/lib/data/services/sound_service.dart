import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../../core/config/app_config.dart';

/// Manages notification and ringtone sounds for the app.
/// Singleton — use `SoundService()` to access.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _messagePlayer = AudioPlayer();
  final AudioPlayer _callEndPlayer = AudioPlayer();

  /// Timer-based ringtone: replays a short clip periodically.
  /// When timer is cancelled, the current short clip finishes and no more play.
  Timer? _ringtoneTimer;
  AudioPlayer? _currentRingtonePlayer;
  bool _callActive = false;

  /// Mark that a call is currently active — blocks all ringtone playback.
  /// MUST be followed by await stopRingtone() to ensure audio is fully stopped.
  void setCallActive(bool active) {
    _callActive = active;
    AppConfig.log('[Sound] Call active: $active');
  }

  /// Play message notification sound (short ding)
  Future<void> playMessageSound() async {
    if (_callActive) return;
    try {
      await _messagePlayer.stop();
      await _messagePlayer.setSource(AssetSource('sounds/message.wav'));
      await _messagePlayer.setVolume(0.5);
      await _messagePlayer.resume();
    } catch (e) {
      AppConfig.log('[Sound] Error playing message sound: $e');
    }
  }

  /// Play incoming call ringtone using a Timer-based approach.
  Future<void> playRingtone() async {
    if (_callActive || _ringtoneTimer != null) return;

    AppConfig.log('[Sound] Starting ringtone (timer-based)');
    await _playRingtoneOnce();

    _ringtoneTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_callActive) {
        stopRingtone();
        return;
      }
      _playRingtoneOnce();
    });
  }

  Future<void> _playRingtoneOnce() async {
    try {
      // Destroy previous player completely before creating new one
      await _killCurrentPlayer();

      _currentRingtonePlayer = AudioPlayer();
      await _currentRingtonePlayer!.setReleaseMode(ReleaseMode.stop);
      await _currentRingtonePlayer!.setSource(
        AssetSource('sounds/ringtone.wav'),
      );
      await _currentRingtonePlayer!.setVolume(0.8);
      await _currentRingtonePlayer!.resume();
    } catch (e) {
      AppConfig.log('[Sound] Error in _playRingtoneOnce: $e');
    }
  }

  /// Stop the ringtone COMPLETELY. This method MUST be awaited.
  Future<void> stopRingtone() async {
    AppConfig.log('[Sound] Stopping ringtone');

    // 1. Cancel the timer so no more replays
    _ringtoneTimer?.cancel();
    _ringtoneTimer = null;

    // 2. Kill the current player and WAIT for it
    await _killCurrentPlayer();

    AppConfig.log('[Sound] Ringtone fully stopped');
  }

  /// Kill the current ringtone player. Awaits all async operations.
  Future<void> _killCurrentPlayer() async {
    if (_currentRingtonePlayer != null) {
      final player = _currentRingtonePlayer!;
      _currentRingtonePlayer = null;
      try {
        await player.pause(); // pause is often faster than stop
      } catch (_) {}
      try {
        await player.setVolume(0);
      } catch (_) {}
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.release();
      } catch (_) {}
      try {
        player.dispose();
      } catch (_) {}
    }
  }

  /// Play call end beep
  Future<void> playCallEnd() async {
    try {
      await stopRingtone();
      await _callEndPlayer.stop();
      await _callEndPlayer.setSource(AssetSource('sounds/call_end.wav'));
      await _callEndPlayer.setVolume(0.5);
      await _callEndPlayer.resume();
    } catch (e) {
      AppConfig.log('[Sound] Error playing call end: $e');
    }
  }

  /// Dispose all players
  void dispose() {
    _ringtoneTimer?.cancel();
    _ringtoneTimer = null;
    _messagePlayer.dispose();
    _currentRingtonePlayer?.dispose();
    _currentRingtonePlayer = null;
    _callEndPlayer.dispose();
  }
}
