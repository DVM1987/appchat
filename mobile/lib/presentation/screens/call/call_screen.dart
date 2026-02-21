import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/agora_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/chat_service.dart';
import '../../widgets/common/custom_avatar.dart';

enum CallType { audio, video }

enum CallState { ringing, connected, ended }

enum CallRole { caller, callee }

class CallScreen extends StatefulWidget {
  final String calleeName;
  final String? calleeAvatar;
  final CallType callType;
  final CallRole callRole;
  final String otherUserId; // The other user's identity ID

  const CallScreen({
    super.key,
    required this.calleeName,
    this.calleeAvatar,
    required this.callType,
    this.callRole = CallRole.caller,
    required this.otherUserId,
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
  final List<String> _debugLogs = []; // Visible debug logs on screen

  void _addLog(String msg) {
    if (mounted) {
      setState(() {
        _debugLogs.add('[${DateTime.now().toString().substring(11, 19)}] $msg');
        if (_debugLogs.length > 15) _debugLogs.removeAt(0);
      });
    }
  }

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
      // Caller: initiate the call
      _initiateCall();

      // Auto-end after 30s if no answer
      _ringTimeout = Timer(const Duration(seconds: 30), () {
        if (mounted && _callState == CallState.ringing) {
          _endCall(showMessage: true);
        }
      });
    }
  }

  void _setupCallListeners() {
    // Listen for call accepted → start Agora
    _chatService.onCallAccepted = () {
      _addLog('📲 CallAccepted received');
      if (mounted && _callState == CallState.ringing) {
        setState(() => _callState = CallState.connected);
        _pulseController.stop();
        _ringTimeout?.cancel();
        _startDurationTimer();
        _initAndJoinAgora(); // 🔊 Start real audio/video
      }
    };

    // Listen for call rejected
    _chatService.onCallRejected = () {
      _addLog('📲 CallRejected received');
      if (mounted && _callState == CallState.ringing) {
        _showCallMessage('Cuộc gọi bị từ chối');
        _endCallSilent();
      }
    };

    // Listen for call ended by other party
    _chatService.onCallEnded = () {
      _addLog('📲 CallEnded received');
      if (mounted && _callState != CallState.ended) {
        _showCallMessage('Cuộc gọi đã kết thúc');
        _endCallSilent();
      }
    };
  }

  /// Initialize Agora engine and join the channel
  Future<void> _initAndJoinAgora() async {
    try {
      final isVideo = widget.callType == CallType.video;
      _addLog('Starting Agora init (video=$isVideo)');

      // Request permissions
      final granted = await _agoraService.requestPermissions(isVideo: isVideo);
      _addLog('Permissions granted: $granted');
      if (!granted) {
        _addLog('❌ PERMISSIONS DENIED');
        _showCallMessage('Cần cấp quyền micro${isVideo ? ' và camera' : ''}');
        return;
      }

      // Setup Agora callbacks BEFORE initializing
      _agoraService.onUserJoined = (int remoteUid) {
        _addLog('🎉 Remote user joined: $remoteUid');
        if (mounted) {
          setState(() => _remoteUid = remoteUid);
        }
      };

      _agoraService.onUserOffline = (int remoteUid) {
        _addLog('❌ Remote user left: $remoteUid');
        if (mounted) {
          setState(() => _remoteUid = null);
        }
      };

      _agoraService.onError = (err, msg) {
        _addLog('❌ Agora Error: $err - $msg');
      };

      // Initialize engine
      _addLog('Initializing engine...');
      await _agoraService.initialize(isVideo: isVideo);
      _addLog('✅ Engine initialized');

      // Generate channel name
      final myUserId = await AuthService.getUserId() ?? '';
      final channelName = AgoraService.generateChannelName(
        myUserId,
        widget.otherUserId,
      );
      final uid = AgoraService.generateUid(myUserId);

      _addLog('myId: ${myUserId.substring(0, 8)}...');
      _addLog('channel: $channelName');
      _addLog('uid: $uid');

      // Store channel name
      if (mounted) {
        setState(() => _channelName = channelName);
      }

      // Try to get token from backend first, fallback to empty (testing mode)
      String agoraToken = '';
      try {
        final backendToken = await _agoraService.getToken(channelName);
        if (backendToken != null && backendToken.isNotEmpty) {
          agoraToken = backendToken;
          _addLog('Got backend token: ${agoraToken.substring(0, 10)}...');
        } else {
          _addLog('No backend token, using testing mode');
        }
      } catch (e) {
        _addLog('Token fetch error: $e');
      }

      // Join channel
      _addLog('Joining channel...');
      await _agoraService.joinChannel(
        channelName: channelName,
        uid: uid,
        token: agoraToken.isNotEmpty ? agoraToken : null,
      );

      // Start local video preview if needed
      if (isVideo) {
        await _agoraService.engine?.startPreview();
        _addLog('Video preview started');
      }

      if (mounted) {
        setState(() => _agoraJoined = true);
      }
      _addLog('✅ Agora joined!');
    } catch (e, stack) {
      _addLog('❌ ERROR: $e');
      _addLog('Stack: ${stack.toString().split('\n').first}');
      _showCallMessage('Lỗi kết nối: $e');
    }
  }

  void _initiateCall() {
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
    _addLog('Accepting call...');
    _chatService.acceptCall(callerId: widget.otherUserId);
    setState(() => _callState = CallState.connected);
    _pulseController.stop();
    _startDurationTimer();
    await _initAndJoinAgora(); // 🔊 Callee also joins Agora
  }

  void _rejectCall() {
    _chatService.rejectCall(callerId: widget.otherUserId);
    _endCallSilent();
  }

  void _endCall({bool showMessage = false}) {
    _chatService.endCall(otherUserId: widget.otherUserId);
    if (showMessage) {
      _showCallMessage('Không có phản hồi');
    }
    _endCallSilent();
  }

  void _endCallSilent() async {
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
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
                // Debug overlay at top
                if (_debugLogs.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _debugLogs
                          .map(
                            (log) => Text(
                              log,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 9,
                                fontFamily: 'monospace',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

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
                                              .withOpacity(0.3),
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
                        Colors.black.withOpacity(0.8),
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
                  color: color.withOpacity(0.5),
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
              color: isActive ? Colors.white : Colors.white.withOpacity(0.15),
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
