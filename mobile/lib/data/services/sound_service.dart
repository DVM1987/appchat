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

  /// Flag to prevent any ringtone from playing during an active call.
  /// Set to true when a call is accepted/connected, false when call ends.
  bool _callActive = false;

  /// Mark that a call is currently active — blocks all ringtone playback
  void setCallActive(bool active) {
    _callActive = active;
    AppConfig.log('[Sound] Call active: $active');
    if (active) {
      // If activating call, force stop any ringtone immediately
      forceStopRingtone();
    }
  }

  /// Play message notification sound (short ding)
  Future<void> playMessageSound() async {
    // Don't play message sounds during active calls
    if (_callActive) return;
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
    // BLOCK ringtone if a call is already active
    if (_callActive) {
      AppConfig.log('[Sound] Ringtone BLOCKED — call is active');
      return;
    }
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
    await _destroyRingtonePlayer();
  }

  /// Force stop — bypasses all guards, destroys everything
  void forceStopRingtone() {
    _isRinging = false;
    _destroyRingtonePlayerSync();
  }

  Future<void> _destroyRingtonePlayer() async {
    try {
      if (_ringtonePlayer != null) {
        final player = _ringtonePlayer!;
        _ringtonePlayer = null; // Null out FIRST to prevent re-use
        // 1. Immediately mute to prevent any audio leak
        try {
          await player.setVolume(0);
        } catch (_) {}
        // 2. Stop playback
        try {
          await player.stop();
        } catch (_) {}
        // 3. Release native resources
        try {
          await player.release();
        } catch (_) {}
        // 4. Dispose Dart-side resources
        try {
          player.dispose();
        } catch (_) {}
        AppConfig.log('[Sound] Ringtone stopped and destroyed');
      }
    } catch (e) {
      AppConfig.log('[Sound] Error destroying ringtone player: $e');
    }
  }

  void _destroyRingtonePlayerSync() {
    try {
      if (_ringtonePlayer != null) {
        final player = _ringtonePlayer!;
        _ringtonePlayer = null;
        try {
          player.setVolume(0);
        } catch (_) {}
        try {
          player.stop();
        } catch (_) {}
        try {
          player.release();
        } catch (_) {}
        try {
          player.dispose();
        } catch (_) {}
        AppConfig.log('[Sound] Ringtone force-destroyed (sync)');
      }
    } catch (e) {
      AppConfig.log('[Sound] Error force-destroying ringtone: $e');
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
