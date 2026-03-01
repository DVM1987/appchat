import 'package:audioplayers/audioplayers.dart';

import '../../core/config/app_config.dart';

/// Manages notification and ringtone sounds for the app.
/// Singleton — use `SoundService()` to access.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _messagePlayer = AudioPlayer();

  // Track all active ringtone players in case of concurrent triggers
  final List<AudioPlayer> _ringtonePlayers = [];

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

    // Explicitly destroy any existing players to avoid overlap
    _destroyAllRingtonePlayersSync();

    if (_isRinging) return;
    try {
      _isRinging = true;
      // Create a fresh player each time to avoid iOS audio session issues
      final player = AudioPlayer();
      _ringtonePlayers.add(player);

      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSource(AssetSource('sounds/ringtone.wav'));
      await player.setVolume(0.8);
      await player.resume();
      AppConfig.log(
        '[Sound] Ringtone started, active players: ${_ringtonePlayers.length}',
      );
    } catch (e) {
      AppConfig.log('[Sound] Error playing ringtone: $e');
      _isRinging = false;
    }
  }

  /// Stop the ringtone — always attempts to stop regardless of _isRinging flag
  Future<void> stopRingtone() async {
    _isRinging = false;
    await _destroyAllRingtonePlayersAsync();
  }

  /// Force stop — bypasses all guards, destroys everything
  void forceStopRingtone() {
    _isRinging = false;
    _destroyAllRingtonePlayersSync();
  }

  Future<void> _destroyAllRingtonePlayersAsync() async {
    AppConfig.log(
      '[Sound] Destroying ${_ringtonePlayers.length} ringtone players (async)',
    );
    // Make a copy and clear the list immediately
    final playersToDestroy = List<AudioPlayer>.from(_ringtonePlayers);
    _ringtonePlayers.clear();

    for (final player in playersToDestroy) {
      try {
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
      } catch (e) {
        AppConfig.log('[Sound] Error destroying a ringtone player: $e');
      }
    }
  }

  void _destroyAllRingtonePlayersSync() {
    if (_ringtonePlayers.isNotEmpty) {
      AppConfig.log(
        '[Sound] Destroying ${_ringtonePlayers.length} ringtone players (sync)',
      );
    }

    final playersToDestroy = List<AudioPlayer>.from(_ringtonePlayers);
    _ringtonePlayers.clear();

    for (final player in playersToDestroy) {
      try {
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
      } catch (e) {
        AppConfig.log('[Sound] Error force-destroying ringtone: $e');
      }
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
    _destroyAllRingtonePlayersSync();
    _callEndPlayer.dispose();
  }
}
