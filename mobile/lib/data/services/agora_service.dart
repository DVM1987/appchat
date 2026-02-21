import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/app_config.dart';
import 'auth_service.dart';

class AgoraService {
  static const String appId = '37cc9df20f2d4cd9860e29b6b4b9517b';

  RtcEngine? _engine;
  bool _isInitialized = false;

  // Callbacks
  void Function(int remoteUid)? onUserJoined;
  void Function(int remoteUid)? onUserOffline;
  void Function(RtcConnection connection, int elapsed)? onJoinChannelSuccess;
  void Function(ErrorCodeType err, String msg)? onError;

  RtcEngine? get engine => _engine;
  bool get isInitialized => _isInitialized;

  /// Request camera and microphone permissions
  Future<bool> requestPermissions({bool isVideo = false}) async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) return false;

    if (isVideo) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) return false;
    }

    return true;
  }

  /// Initialize the Agora RTC engine
  Future<void> initialize({bool isVideo = false}) async {
    if (_isInitialized && _engine != null) {
      // If already initialized, just enable/disable video as needed
      if (isVideo) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      }
      print('[Agora] Already initialized, reusing engine');
      return;
    }

    // Ensure clean state before creating new engine
    if (_engine != null) {
      try {
        await _engine!.release();
      } catch (_) {}
      _engine = null;
      _isInitialized = false;
    }

    print('[Agora] Creating engine with appId: ${appId.substring(0, 8)}...');
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    // Register event handler
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print(
            '[Agora] ✅ Joined channel: ${connection.channelId} in ${elapsed}ms',
          );
          onJoinChannelSuccess?.call(connection, elapsed);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('[Agora] ✅ Remote user joined: $remoteUid');
          onUserJoined?.call(remoteUid);
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              print(
                '[Agora] ❌ Remote user offline: $remoteUid reason: $reason',
              );
              onUserOffline?.call(remoteUid);
            },
        onError: (ErrorCodeType err, String msg) {
          print('[Agora] ❌ Error: $err - $msg');
          onError?.call(err, msg);
        },
        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              print('[Agora] 🔄 Connection state: $state reason: $reason');
            },
      ),
    );

    // Always enable audio
    await _engine!.enableAudio();
    await _engine!.setEnableSpeakerphone(false); // earpiece by default
    print('[Agora] Audio enabled');

    if (isVideo) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
      print('[Agora] Video enabled + preview started');
    }

    _isInitialized = true;
    print('[Agora] ✅ Engine initialized (video=$isVideo)');
  }

  /// Get Agora token from backend
  Future<String?> getToken(String channelName) async {
    try {
      final authToken = await AuthService.getToken();
      if (authToken == null) return null;

      final response = await http.get(
        Uri.parse(
          '${AppConfig.chatApiBaseUrl}/agora/token?channelName=$channelName',
        ),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'] as String?;
      } else {
        AppConfig.log('[Agora] Failed to get token: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppConfig.log('[Agora] Error getting token: $e');
      return null;
    }
  }

  /// Join a channel
  Future<void> joinChannel({
    required String channelName,
    required int uid,
    String? token,
  }) async {
    if (_engine == null) {
      print('[Agora] ❌ Engine is null, cannot join');
      return;
    }

    // Testing Mode (APP ID only) - no token needed
    final agoraToken = token ?? '';

    print('[Agora] 📞 Joining channel: $channelName with uid: $uid');

    await _engine!.joinChannel(
      token: agoraToken,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishMicrophoneTrack: true,
        publishCameraTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    print('[Agora] ✅ Join channel request sent for: $channelName');
  }

  /// Leave the current channel
  Future<void> leaveChannel() async {
    if (_engine == null) return;
    await _engine!.leaveChannel();
    AppConfig.log('[Agora] Left channel');
  }

  /// Toggle mute local audio
  Future<void> toggleMute(bool mute) async {
    await _engine?.muteLocalAudioStream(mute);
  }

  /// Toggle speaker phone
  Future<void> toggleSpeaker(bool enable) async {
    await _engine?.setEnableSpeakerphone(enable);
  }

  /// Toggle local video
  Future<void> toggleCamera(bool disable) async {
    if (disable) {
      await _engine?.muteLocalVideoStream(true);
    } else {
      await _engine?.muteLocalVideoStream(false);
    }
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  /// Dispose the engine
  Future<void> dispose() async {
    if (_engine != null) {
      try {
        await _engine!.leaveChannel();
      } catch (e) {
        print('[Agora] Warning: leaveChannel error: $e');
      }
      try {
        await _engine!.release();
      } catch (e) {
        print('[Agora] Warning: release error: $e');
      }
      _engine = null;
      _isInitialized = false;
      // Clear callbacks to avoid stale references
      onUserJoined = null;
      onUserOffline = null;
      onJoinChannelSuccess = null;
      onError = null;
      print('[Agora] Engine disposed');
    }
  }

  /// Generate a deterministic UID from a userId string
  static int generateUid(String userId) {
    // Create a hash and take lower 31 bits to ensure positive int
    int hash = userId.hashCode & 0x7FFFFFFF;
    // Agora UIDs should be non-zero
    return hash == 0 ? 1 : hash;
  }

  /// Generate channel name for a 1-on-1 call
  /// Sort both user IDs to ensure both parties get the same channel name
  static String generateChannelName(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    final id1 = sorted[0].length >= 8 ? sorted[0].substring(0, 8) : sorted[0];
    final id2 = sorted[1].length >= 8 ? sorted[1].substring(0, 8) : sorted[1];
    return 'call_${id1}_$id2';
  }
}
