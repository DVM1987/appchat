import 'package:audioplayers/audioplayers.dart';

import '../../core/config/app_config.dart';

/// Manages notification and ringtone sounds for the app.
/// Singleton — use `SoundService()` to access.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _messagePlayer = AudioPlayer();
  AudioPlayer? _ringtonePlayer;
  final AudioPlayer _callEndPlayer = AudioPlayer();

  bool _isRinging = false;

  /// Play message notification sound (short ding)
  Future<void> playMessageSound() async {
    try {
      await _messagePlayer.stop();
      await _messagePlayer.setSource(AssetSource('sounds/message.wav'));
      await _messagePlayer.setVolume(0.5);
      await _messagePlayer.resume();
      AppConfig.log('[Sound] Message notification played');
    } catch (e) {
      AppConfig.log('[Sound] Error playing message sound: $e');
    }
  }

  /// Play incoming call ringtone (loops until stopped)
  Future<void> playRingtone() async {
    if (_isRinging) return;
    try {
      _isRinging = true;
      // Create a fresh player each time to avoid iOS audio session issues
      _ringtonePlayer?.dispose();
      _ringtonePlayer = AudioPlayer();
      await _ringtonePlayer!.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer!.setSource(AssetSource('sounds/ringtone.wav'));
      await _ringtonePlayer!.setVolume(0.8);
      await _ringtonePlayer!.resume();
      AppConfig.log('[Sound] Ringtone started');
    } catch (e) {
      AppConfig.log('[Sound] Error playing ringtone: $e');
      _isRinging = false;
    }
  }

  /// Stop the ringtone — always attempts to stop regardless of _isRinging flag
  Future<void> stopRingtone() async {
    _isRinging = false;
    try {
      if (_ringtonePlayer != null) {
        // 1. Immediately mute to prevent any audio leak
        await _ringtonePlayer!.setVolume(0);
        // 2. Stop playback
        await _ringtonePlayer!.stop();
        // 3. Release and destroy the player to fully free audio resources
        await _ringtonePlayer!.release();
        _ringtonePlayer!.dispose();
        _ringtonePlayer = null;
        AppConfig.log('[Sound] Ringtone stopped and released');
      }
    } catch (e) {
      AppConfig.log('[Sound] Error stopping ringtone: $e');
      // Force cleanup even on error
      try {
        _ringtonePlayer?.dispose();
      } catch (_) {}
      _ringtonePlayer = null;
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
      AppConfig.log('[Sound] Call end played');
    } catch (e) {
      AppConfig.log('[Sound] Error playing call end: $e');
    }
  }

  /// Dispose all players
  void dispose() {
    _messagePlayer.dispose();
    _ringtonePlayer?.dispose();
    _ringtonePlayer = null;
    _callEndPlayer.dispose();
  }
}
