import 'package:audioplayers/audioplayers.dart';

import '../../core/config/app_config.dart';

/// Manages notification and ringtone sounds for the app.
/// Singleton — use `SoundService()` to access.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _messagePlayer = AudioPlayer();
  final AudioPlayer _ringtonePlayer = AudioPlayer();
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
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.setSource(AssetSource('sounds/ringtone.wav'));
      await _ringtonePlayer.setVolume(0.8);
      await _ringtonePlayer.resume();
      AppConfig.log('[Sound] Ringtone started');
    } catch (e) {
      AppConfig.log('[Sound] Error playing ringtone: $e');
      _isRinging = false;
    }
  }

  /// Stop the ringtone
  Future<void> stopRingtone() async {
    if (!_isRinging) return;
    try {
      _isRinging = false;
      await _ringtonePlayer.stop();
      AppConfig.log('[Sound] Ringtone stopped');
    } catch (e) {
      AppConfig.log('[Sound] Error stopping ringtone: $e');
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
    _ringtonePlayer.dispose();
    _callEndPlayer.dispose();
  }
}
