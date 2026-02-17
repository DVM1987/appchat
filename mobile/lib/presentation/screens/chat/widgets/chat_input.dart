import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:record/record.dart';

import '../../../../core/config/app_config.dart';
import 'image_preview_dialog.dart';
import 'mentions_list.dart';

class ChatInput extends StatefulWidget {
  final Function(String text, {String? replyToId, String? replyToContent})?
  onSend;
  final Function(List<File> images)? onSendImages;
  final Function(File voiceFile)? onSendVoice;
  final VoidCallback? onTyping;
  final List<Map<String, dynamic>> members; // Added members list
  final bool isGroup;
  final Map<String, dynamic>? replyToMessage;
  final VoidCallback? onCancelReply;

  const ChatInput({
    super.key,
    this.onSend,
    this.onSendImages,
    this.onSendVoice,
    this.onTyping,
    this.members = const [],
    this.isGroup = false,
    this.replyToMessage,
    this.onCancelReply,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isComposing = false;
  bool _isAttachmentSheetOpen = false;
  bool _isUploadingImages = false;

  // Voice recording state
  bool _isVoiceRecording = false;
  bool _isRecordingPaused = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  final List<double> _waveformData = [];
  final Random _random = Random();
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;

  // Mentions logic
  bool _showMentions = false;
  String _mentionQuery = '';
  int _cursorPosition = 0;

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyToMessage != null && oldWidget.replyToMessage == null) {
      _focusNode.requestFocus();
    }
  }

  void _handleSend() {
    if (_controller.text.trim().isEmpty) return;

    widget.onSend?.call(
      _controller.text.trim(),
      replyToId: widget.replyToMessage?['id'] ?? widget.replyToMessage?['Id'],
      replyToContent:
          widget.replyToMessage?['content'] ??
          widget.replyToMessage?['Content'],
    );

    _controller.clear();
    setState(() {
      _isComposing = false;
      _showMentions = false;
    });
  }

  void _onChanged(String text) {
    setState(() {
      _isComposing = text.trim().isNotEmpty;
    });
    widget.onTyping?.call();

    if (!widget.isGroup) return;

    // Detect @ for mentions
    final cursorPosition = _controller.selection.baseOffset;
    if (cursorPosition < 0) return;

    final textBeforeCursor = text.substring(0, cursorPosition);
    AppConfig.log('ChatInput: textBeforeCursor: "$textBeforeCursor"');
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex != -1) {
      // Check if @ is at start or preceded by space
      if (lastAtIndex == 0 || textBeforeCursor[lastAtIndex - 1] == ' ') {
        final query = textBeforeCursor.substring(lastAtIndex + 1);
        AppConfig.log('ChatInput: Mention detected, query: "$query"');
        // Only show if query doesn't contain spaces (or keep it simple for now)
        if (!query.contains(' ')) {
          setState(() {
            _showMentions = true;
            _mentionQuery = query.toLowerCase();
            _cursorPosition = cursorPosition;
          });
          return;
        }
      }
    }

    if (_showMentions) {
      setState(() {
        _showMentions = false;
      });
    }
  }

  void _insertMention(Map<String, dynamic> member) {
    final text = _controller.text;
    final textBeforeCursor = text.substring(0, _cursorPosition);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    final name = member['fullName'] ?? 'User';
    final newText = text.replaceRange(lastAtIndex, _cursorPosition, '@$name ');

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (lastAtIndex + name.length + 2).toInt(), // +@ and +space
      ),
    );

    setState(() {
      _showMentions = false;
    });
  }

  void _toggleAttachmentSheet() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isAttachmentSheetOpen = !_isAttachmentSheetOpen;
    });
  }

  Future<void> _pickImages() async {
    // Close the attachment sheet
    setState(() {
      _isAttachmentSheetOpen = false;
    });

    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFiles.isEmpty) return;

      final files = pickedFiles.map((xf) => File(xf.path)).toList();

      // Show preview dialog before sending
      if (!mounted) return;
      final shouldSend = await showImagePreviewDialog(context, files);

      if (shouldSend == true && mounted) {
        setState(() => _isUploadingImages = true);
        try {
          widget.onSendImages?.call(files);
        } finally {
          if (mounted) {
            setState(() => _isUploadingImages = false);
          }
        }
      }
    } catch (e) {
      AppConfig.log('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
      }
    }
  }

  Future<void> _pickCameraImage() async {
    setState(() {
      _isAttachmentSheetOpen = false;
    });

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo == null) return;

      final files = [File(photo.path)];

      if (!mounted) return;
      final shouldSend = await showImagePreviewDialog(context, files);

      if (shouldSend == true && mounted) {
        setState(() => _isUploadingImages = true);
        try {
          widget.onSendImages?.call(files);
        } finally {
          if (mounted) {
            setState(() => _isUploadingImages = false);
          }
        }
      }
    } catch (e) {
      AppConfig.log('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi chụp ảnh: $e')));
      }
    }
  }

  // Removed _showImagePreviewDialog — now uses showImagePreviewDialog()

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    final width = (MediaQuery.of(context).size.width - 40 - 16 * 3) / 4;

    return SizedBox(
      width: width.clamp(70.0, 98.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap ?? () {},
            borderRadius: BorderRadius.circular(36),
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Icon(icon, color: iconColor, size: 34),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPanel() {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.white,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomSafe),
        child: Wrap(
          spacing: 16,
          runSpacing: 22,
          children: [
            _buildAttachmentOption(
              icon: Icons.image_outlined,
              label: 'Ảnh',
              iconColor: const Color(0xFF3BA9FF),
              onTap: _pickImages,
            ),
            _buildAttachmentOption(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              iconColor: Colors.white,
              onTap: _pickCameraImage,
            ),
            _buildAttachmentOption(
              icon: Icons.location_on_outlined,
              label: 'Vị trí',
              iconColor: const Color(0xFF1DD7A7),
            ),
            _buildAttachmentOption(
              icon: Icons.person_outline,
              label: 'Người liên hệ',
              iconColor: Colors.white,
            ),
            _buildAttachmentOption(
              icon: Icons.insert_drive_file_outlined,
              label: 'Tài liệu',
              iconColor: const Color(0xFF2AB6FF),
            ),
            _buildAttachmentOption(
              icon: Icons.poll_outlined,
              label: 'Thăm dò ý kiến',
              iconColor: const Color(0xFFFFC53D),
            ),
            _buildAttachmentOption(
              icon: Icons.calendar_month_outlined,
              label: 'Sự kiện',
              iconColor: const Color(0xFFFF2E63),
            ),
            _buildAttachmentOption(
              icon: Icons.auto_awesome_outlined,
              label: 'Hình ảnh AI',
              iconColor: const Color(0xFF49A8FF),
            ),
          ],
        ),
      ),
    );
  }

  // ── Voice Recording Methods ──

  Future<void> _startVoiceRecording() async {
    // Check permission
    if (!await _audioRecorder.hasPermission()) {
      return;
    }

    // Generate temp file path
    final tempDir = await getTemporaryDirectory();
    _recordingPath =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // Start recording
    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _recordingPath!,
    );

    setState(() {
      _isVoiceRecording = true;
      _isRecordingPaused = false;
      _recordingSeconds = 0;
      _waveformData.clear();
      _isAttachmentSheetOpen = false;
    });
    _focusNode.unfocus();
    _startRecordingTimer();
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) {
      if (!_isRecordingPaused) {
        setState(() {
          // Update seconds every 5 ticks (= 1 second)
          if (timer.tick % 5 == 0) _recordingSeconds++;
          // Add waveform data point at each tick for smoother animation
          _waveformData.add(_random.nextDouble() * 0.7 + 0.15);
        });
      }
    });
  }

  Future<void> _toggleRecordingPause() async {
    if (_isRecordingPaused) {
      await _audioRecorder.resume();
    } else {
      await _audioRecorder.pause();
    }
    setState(() {
      _isRecordingPaused = !_isRecordingPaused;
    });
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _audioRecorder.stop();
    // Delete temp file
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (await file.exists()) await file.delete();
    }
    setState(() {
      _isVoiceRecording = false;
      _isRecordingPaused = false;
      _recordingSeconds = 0;
      _waveformData.clear();
      _recordingPath = null;
    });
  }

  Future<void> _sendVoiceRecording() async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();

    setState(() {
      _isVoiceRecording = false;
      _isRecordingPaused = false;
      _recordingSeconds = 0;
      _waveformData.clear();
    });

    if (path != null && path.isNotEmpty) {
      final voiceFile = File(path);
      if (await voiceFile.exists()) {
        widget.onSendVoice?.call(voiceFile);
      }
    }
    _recordingPath = null;
  }

  String _formatRecordingTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildVoiceRecordingPanel() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top Row: Timer | Waveform | Counter ──
              Row(
                children: [
                  // Timer
                  Text(
                    _formatRecordingTime(_recordingSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Waveform
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          data: _waveformData,
                          isPaused: _isRecordingPaused,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Circular counter (simulates playback speed / count)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white38,
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '1',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ── Bottom Row: Delete | Pause | Send ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Delete button
                  GestureDetector(
                    onTap: _cancelVoiceRecording,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  // Pause / Resume button
                  GestureDetector(
                    onTap: _toggleRecordingPause,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF3B5C),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        _isRecordingPaused
                            ? Icons.fiber_manual_record
                            : Icons.pause,
                        color: const Color(0xFFFF3B5C),
                        size: _isRecordingPaused ? 28 : 32,
                      ),
                    ),
                  ),
                  // Send button
                  GestureDetector(
                    onTap: _sendVoiceRecording,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFF25D366),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If voice recording is active, show recording panel instead
    if (_isVoiceRecording) {
      return _buildVoiceRecordingPanel();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showMentions && widget.members.isNotEmpty) _buildMentionsList(),
        if (widget.replyToMessage != null) _buildReplyPreview(),
        // Uploading images indicator
        if (_isUploadingImages)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.white,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Đang gửi ảnh...',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.white,
          child: SafeArea(
            top: false,
            bottom: !_isAttachmentSheetOpen,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isAttachmentSheetOpen
                        ? Icons.keyboard_alt_outlined
                        : Icons.add,
                    color: Colors.blue,
                  ),
                  onPressed: _toggleAttachmentSheet,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onTap: () {
                              if (_isAttachmentSheetOpen) {
                                setState(() {
                                  _isAttachmentSheetOpen = false;
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              hintText: 'Tin nhắn',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            onChanged: _onChanged,
                            onSubmitted: (text) => _handleSend(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.sticky_note_2_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isComposing)
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _handleSend,
                  )
                else ...[
                  IconButton(
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.blue,
                    ),
                    onPressed: _pickCameraImage,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.mic_none_outlined,
                      color: Colors.blue,
                    ),
                    onPressed: _startVoiceRecording,
                  ),
                ],
              ],
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: 1.0,
              child: child,
            );
          },
          child: _isAttachmentSheetOpen
              ? _buildAttachmentPanel()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    final replyTo = widget.replyToMessage!;
    final content = replyTo['content'] ?? replyTo['Content'] ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Trả lời tin nhắn',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildMentionsList() {
    return MentionsList(
      members: widget.members,
      mentionQuery: _mentionQuery,
      onMentionSelected: _insertMention,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }
}

// ── Waveform Painter ──

class _WaveformPainter extends CustomPainter {
  final List<double> data;
  final bool isPaused;

  _WaveformPainter({required this.data, required this.isPaused});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      // Draw placeholder dots when no data
      final dotPaint = Paint()
        ..color = Colors.white24
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3;
      final spacing = 6.0;
      final count = (size.width / spacing).floor();
      for (var i = 0; i < count; i++) {
        final x = i * spacing + spacing / 2;
        canvas.drawCircle(Offset(x, size.height / 2), 1.5, dotPaint);
      }
      return;
    }

    final barWidth = 2.5;
    final spacing = 3.5;
    final totalBarWidth = barWidth + spacing;
    final maxBars = (size.width / totalBarWidth).floor();

    // Take only the last N bars that fit
    final visibleData = data.length > maxBars
        ? data.sublist(data.length - maxBars)
        : data;

    final paint = Paint()
      ..color = isPaused ? Colors.white38 : Colors.white70
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final centerY = size.height / 2;
    final maxAmplitude = size.height * 0.45;

    for (var i = 0; i < visibleData.length; i++) {
      final x = i * totalBarWidth + barWidth / 2;
      final amplitude = visibleData[i] * maxAmplitude;
      canvas.drawLine(
        Offset(x, centerY - amplitude),
        Offset(x, centerY + amplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.data.length != data.length ||
        oldDelegate.isPaused != isPaused;
  }
}
