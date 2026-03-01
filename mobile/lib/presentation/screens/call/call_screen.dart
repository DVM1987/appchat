import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/call_log_model.dart' as call_log;
import '../../../data/models/call_log_model.dart' hide CallType;
import '../../../data/services/agora_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/call_log_service.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/sound_service.dart';
import '../../providers/call_log_provider.dart';
import '../../widgets/common/custom_avatar.dart';

enum CallType { audio, video }

enum CallState { ringing, connected, ended }

enum CallRole { caller, callee }

class CallScreen extends StatefulWidget {
  final String calleeName;
  final String? calleeAvatar;
  final CallType callType;
  final CallRole callRole;
  final String otherUserId;
  final String? callLogId; // Existing log ID (for callee), null for caller

  const CallScreen({
    super.key,
    required this.calleeName,
    this.calleeAvatar,
    required this.callType,
    this.callRole = CallRole.caller,
    required this.otherUserId,
    this.callLogId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  CallState _callState = CallState.ringing;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isCameraOff = false;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  Timer? _ringTimeout;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final _chatService = ChatService();
  final _agoraService = AgoraService();

  int? _remoteUid;
  bool _agoraJoined = false;
  String? _channelName;
  String? _callLogId; // Track the call log ID for updating
  DateTime? _connectedAt; // Track when call connected for duration calc

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen for call signals
    _setupCallListeners();

    if (widget.callRole == CallRole.caller) {
      // Caller: initiate the call and record outgoing log
      _recordOutgoingLog();
      _initiateCall();

      // Auto-end after 30s if no answer
      _ringTimeout = Timer(const Duration(seconds: 30), () {
        if (mounted && _callState == CallState.ringing) {
          _endCall(showMessage: true);
        }
      });
    } else {
      // Callee: callLogId is already set from home_screen
      _callLogId = widget.callLogId;
    }
  }

  void _recordOutgoingLog() {
    final id = CallLogService.generateId();
    _callLogId = id;
    final log = CallLog(
      id: id,
      otherUserId: widget.otherUserId,
      otherUserName: widget.calleeName,
      otherUserAvatar: widget.calleeAvatar,
      callType: widget.callType == CallType.video
          ? call_log.CallType.video
          : call_log.CallType.audio,
      direction: CallDirection.outgoing,
      status: CallStatus.missed, // Default missed, updated if connected
      startedAt: DateTime.now(),
    );
    try {
      context.read<CallLogProvider>().addLog(log);
    } catch (_) {
      // Provider might not be available in widget tree
      CallLogService().addLog(log);
    }
  }

  void _setupCallListeners() {
    // Listen for call accepted (CALLER side) → start Agora
    _chatService.onCallAccepted = () {
      AppConfig.log('[Call] Received CallAccepted signal');
      // Mark call active FIRST — blocks any further ringtone playback
      SoundService().setCallActive(true);
      if (mounted && _callState == CallState.ringing) {
        setState(() => _callState = CallState.connected);
        _connectedAt = DateTime.now();
        _pulseController.stop();
        _ringTimeout?.cancel();
        _startDurationTimer();
        _updateLogStatus(CallStatus.completed);
        _initAndJoinAgora();
      }
    };

    // Listen for call rejected
    _chatService.onCallRejected = () {
      SoundService().setCallActive(false);
      SoundService().stopRingtone();
      if (mounted && _callState == CallState.ringing) {
        _updateLogStatus(CallStatus.rejected);
        _showCallMessage('Cuộc gọi bị từ chối');
        _endCallSilent();
      }
    };

    // Listen for call ended by other party
    _chatService.onCallEnded = () {
      SoundService().setCallActive(false);
      SoundService().stopRingtone();
      if (mounted && _callState != CallState.ended) {
        _updateLogDuration();
        _showCallMessage('Cuộc gọi đã kết thúc');
        _endCallSilent();
      }
    };
  }

  void _updateLogStatus(CallStatus status) {
    if (_callLogId == null) return;
    try {
      context.read<CallLogProvider>().updateLog(_callLogId!, status: status);
    } catch (_) {
      CallLogService().updateLog(_callLogId!, status: status);
    }
  }

  void _updateLogDuration() {
    if (_callLogId == null || _connectedAt == null) return;
    final duration = DateTime.now().difference(_connectedAt!).inSeconds;
    try {
      context.read<CallLogProvider>().updateLog(
        _callLogId!,
        status: CallStatus.completed,
        durationSeconds: duration,
      );
    } catch (_) {
      CallLogService().updateLog(
        _callLogId!,
        status: CallStatus.completed,
        durationSeconds: duration,
      );
    }
  }

  /// Initialize Agora engine and join the channel
  Future<void> _initAndJoinAgora() async {
    try {
      final isVideo = widget.callType == CallType.video;
      AppConfig.log('[Call] _initAndJoinAgora: isVideo=$isVideo');

      // Request permissions
      final granted = await _agoraService.requestPermissions(isVideo: isVideo);
      if (!granted) {
        _showCallMessage('Cần cấp quyền micro${isVideo ? ' và camera' : ''}');
        AppConfig.log('[Call] Permission denied');
        return;
      }
      AppConfig.log('[Call] Permissions granted');

      // Setup Agora callbacks BEFORE initializing
      _agoraService.onUserJoined = (int remoteUid) {
        AppConfig.log('[Call] Remote user joined: $remoteUid');
        if (mounted) {
          setState(() => _remoteUid = remoteUid);
        }
      };

      _agoraService.onUserOffline = (int remoteUid) {
        AppConfig.log('[Call] Remote user left: $remoteUid');
        if (mounted) {
          setState(() => _remoteUid = null);
        }
      };

      _agoraService.onJoinChannelSuccess = (connection, elapsed) {
        AppConfig.log(
          '[Call] Join channel success: channel=${connection.channelId}, uid=${connection.localUid}, elapsed=$elapsed ms',
        );
      };

      _agoraService.onError = (err, msg) {
        AppConfig.log('[Call] Agora Error: $err - $msg');
      };

      // Initialize engine
      AppConfig.log('[Call] Initializing Agora engine...');
      await _agoraService.initialize(isVideo: isVideo);
      AppConfig.log('[Call] Agora engine initialized');

      // Generate channel name
      final myUserId = await AuthService.getUserId() ?? '';
      final channelName = AgoraService.generateChannelName(
        myUserId,
        widget.otherUserId,
      );
      final uid = AgoraService.generateUid(myUserId);
      AppConfig.log(
        '[Call] Channel=$channelName, UID=$uid, myUserId=$myUserId, otherUserId=${widget.otherUserId}',
      );

      // Store channel name
      if (mounted) {
        setState(() => _channelName = channelName);
      }

      // Try to get token from backend first, fallback to empty (testing mode)
      String? agoraToken;
      try {
        agoraToken = await _agoraService.getToken(channelName);
        AppConfig.log(
          '[Call] Backend token: ${agoraToken != null ? "received" : "null (testing mode)"}',
        );
      } catch (e) {
        AppConfig.log('[Call] Token fetch error (will use testing mode): $e');
      }

      // Join channel
      AppConfig.log(
        '[Call] Joining channel $channelName with uid=$uid, hasToken=${agoraToken != null}',
      );
      await _agoraService.joinChannel(
        channelName: channelName,
        uid: uid,
        token: agoraToken,
      );
      AppConfig.log('[Call] joinChannel called successfully');

      // Start local video preview if needed
      if (isVideo) {
        await _agoraService.engine?.startPreview();
        AppConfig.log('[Call] Video preview started');
      }

      if (mounted) {
        setState(() => _agoraJoined = true);
      }
      AppConfig.log('[Call] _initAndJoinAgora completed successfully');
    } catch (e, stackTrace) {
      AppConfig.log('[Call] _initAndJoinAgora ERROR: $e');
      AppConfig.log('[Call] StackTrace: $stackTrace');
      _showCallMessage('Lỗi kết nối: $e');
    }
  }

  void _initiateCall() {
    AppConfig.log(
      '[Call] Initiating call to ${widget.otherUserId}, type=${widget.callType == CallType.video ? "video" : "audio"}',
    );
    AppConfig.log('[Call] ChatHub state: ${_chatService.chatHubState}');
    _chatService.initiateCall(
      calleeId: widget.otherUserId,
      callType: widget.callType == CallType.video ? 'video' : 'audio',
    );
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
        });
      }
    });
  }

  String get _formattedDuration {
    final minutes = _callDuration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _callDuration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final hours = _callDuration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _acceptCall() async {
    AppConfig.log('[Call] Accepting call from ${widget.otherUserId}');
    // CRITICAL: Block future ringtones AND await full stop before Agora
    SoundService().setCallActive(true);
    await SoundService()
        .stopRingtone(); // MUST await to ensure audio is fully released
    // Extra safety delay to let iOS audio session fully release
    await Future.delayed(const Duration(milliseconds: 500));
    _chatService.acceptCall(callerId: widget.otherUserId);
    setState(() => _callState = CallState.connected);
    _connectedAt = DateTime.now();
    _pulseController.stop();
    _startDurationTimer();
    _updateLogStatus(CallStatus.completed);
    await _initAndJoinAgora(); // 🔊 Callee also joins Agora
  }

  void _rejectCall() {
    SoundService().setCallActive(false);
    SoundService().stopRingtone();
    _updateLogStatus(CallStatus.rejected);
    _chatService.rejectCall(callerId: widget.otherUserId);
    _endCallSilent();
  }

  void _endCall({bool showMessage = false}) {
    _updateLogDuration();
    _chatService.endCall(otherUserId: widget.otherUserId);
    if (showMessage) {
      _showCallMessage('Không có phản hồi');
    }
    _endCallSilent();
  }

  void _endCallSilent() async {
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    // Release call-active lock and stop ringtone
    SoundService().setCallActive(false);
    SoundService().stopRingtone();
    setState(() => _callState = CallState.ended);

    // Leave Agora channel and dispose
    await _agoraService.dispose();

    // Clear listeners
    _chatService.onCallAccepted = null;
    _chatService.onCallRejected = null;
    _chatService.onCallEnded = null;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _showCallMessage(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _agoraService.toggleMute(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeaker = !_isSpeaker);
    _agoraService.toggleSpeaker(_isSpeaker);
  }

  void _toggleCamera() {
    setState(() => _isCameraOff = !_isCameraOff);
    _agoraService.toggleCamera(_isCameraOff);
  }

  void _switchCamera() {
    _agoraService.switchCamera();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    // Release call-active lock and cleanup ringtone
    SoundService().setCallActive(false);
    SoundService().stopRingtone();
    _pulseController.dispose();
    _agoraService.dispose();

    // Clean up listeners
    _chatService.onCallAccepted = null;
    _chatService.onCallRejected = null;
    _chatService.onCallEnded = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == CallType.video;
    final isCaller = widget.callRole == CallRole.caller;
    final isCallee = widget.callRole == CallRole.callee;
    final isRinging = _callState == CallState.ringing;
    final isConnected = _callState == CallState.connected;

    return Scaffold(
      backgroundColor: isVideo ? Colors.black : const Color(0xFF1B2838),
      body: Stack(
        children: [
          // Background — remote video or gradient
          if (isVideo &&
              isConnected &&
              _remoteUid != null &&
              _agoraJoined &&
              _channelName != null)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _agoraService.engine!,
                canvas: VideoCanvas(uid: _remoteUid!),
                connection: RtcConnection(channelId: _channelName!),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isVideo
                      ? [Colors.blueGrey.shade900, Colors.black87]
                      : [const Color(0xFF1B2838), const Color(0xFF0F1923)],
                ),
              ),
            ),

          // Self PiP for video
          if (isVideo && isConnected && _agoraJoined)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: _switchCamera,
                child: Container(
                  width: 100,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: _isCameraOff
                      ? Center(
                          child: Icon(
                            Icons.videocam_off,
                            color: Colors.white30,
                            size: 32,
                          ),
                        )
                      : AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: _agoraService.engine!,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        ),
                ),
              ),
            ),

          // Main content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with pulse (hide when video is connected)
                if (!(isVideo && isConnected && _remoteUid != null))
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isRinging ? _pulseAnimation.value : 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: isRinging
                                ? [
                                    BoxShadow(
                                      color:
                                          (isCallee
                                                  ? Colors.green
                                                  : AppColors.primary)
                                              .withValues(alpha: 0.3),
                                      blurRadius: 30,
                                      spreadRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                          child: CustomAvatar(
                            imageUrl: widget.calleeAvatar,
                            name: widget.calleeName,
                            size: 120,
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // Name
                Text(
                  widget.calleeName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Status
                Text(
                  _getStatusText(isCaller, isCallee, isRinging, isConnected),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isConnected
                        ? AppColors.primary
                        : isCallee && isRinging
                        ? Colors.greenAccent
                        : Colors.white60,
                    fontSize: 16,
                    fontWeight: isConnected
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),

                const Spacer(),

                // Controls
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Callee ringing: show Accept / Reject
                      if (isCallee && isRinging)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Reject button
                            _buildActionButton(
                              icon: Icons.call_end,
                              color: Colors.red,
                              label: 'Từ chối',
                              onTap: _rejectCall,
                              size: 70,
                            ),
                            // Accept button
                            _buildActionButton(
                              icon: isVideo ? Icons.videocam : Icons.call,
                              color: Colors.green,
                              label: 'Nghe',
                              onTap: _acceptCall,
                              size: 70,
                            ),
                          ],
                        ),

                      // Caller ringing: only End call
                      if (isCaller && isRinging) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: _buildActionButton(
                            icon: Icons.call_end,
                            color: Colors.red,
                            label: 'Huỷ',
                            onTap: () => _endCall(),
                            size: 70,
                          ),
                        ),
                      ],

                      // Connected: show controls
                      if (isConnected) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              icon: _isMuted ? Icons.mic_off : Icons.mic,
                              label: _isMuted ? 'Bật mic' : 'Tắt mic',
                              isActive: _isMuted,
                              onTap: _toggleMute,
                            ),
                            if (isVideo)
                              _buildControlButton(
                                icon: _isCameraOff
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                                label: _isCameraOff
                                    ? 'Bật camera'
                                    : 'Tắt camera',
                                isActive: _isCameraOff,
                                onTap: _toggleCamera,
                              ),
                            _buildControlButton(
                              icon: _isSpeaker
                                  ? Icons.volume_up
                                  : Icons.volume_down,
                              label: _isSpeaker ? 'Tắt loa' : 'Bật loa',
                              isActive: _isSpeaker,
                              onTap: _toggleSpeaker,
                            ),
                            if (isVideo)
                              _buildControlButton(
                                icon: Icons.cameraswitch,
                                label: 'Đổi camera',
                                onTap: _switchCamera,
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        _buildActionButton(
                          icon: Icons.call_end,
                          color: Colors.red,
                          label: 'Kết thúc',
                          onTap: () => _endCall(),
                          size: 70,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(
    bool isCaller,
    bool isCallee,
    bool isRinging,
    bool isConnected,
  ) {
    if (isConnected) return _formattedDuration;
    if (_callState == CallState.ended) return 'Cuộc gọi đã kết thúc';
    if (isCallee) {
      return widget.callType == CallType.video
          ? 'Cuộc gọi video đến...'
          : 'Cuộc gọi đến...';
    }
    return widget.callType == CallType.video
        ? 'Đang gọi video...'
        : 'Đang gọi...';
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    double size = 60,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
