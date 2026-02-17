import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Standalone widget that plays a voice message from a URL.
/// Used inside [MessageBubble] for type == 4 (Voice).
class VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final bool isMe;

  const VoiceMessagePlayer({super.key, required this.url, required this.isMe});

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _setupPlayer();
  }

  void _setupPlayer() {
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (!_isLoaded) {
        await _player.setSource(UrlSource(widget.url));
        _isLoaded = true;
      }
      await _player.resume();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isMe
        ? const Color(0xFF25D366)
        : const Color(0xFF3BA9FF);
    final sliderActive = widget.isMe
        ? const Color(0xFF25D366)
        : const Color(0xFF3BA9FF);
    final sliderInactive = Colors.grey[300]!;

    final displayDuration = _isPlaying || _position > Duration.zero
        ? _position
        : _duration;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play / Pause button
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Slider + duration
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  activeTrackColor: sliderActive,
                  inactiveTrackColor: sliderInactive,
                  thumbColor: sliderActive,
                ),
                child: Slider(
                  min: 0,
                  max: _duration.inMilliseconds > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1.0,
                  value: _position.inMilliseconds.toDouble().clamp(
                    0,
                    _duration.inMilliseconds > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                  ),
                  onChanged: (value) {
                    _player.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
            ],
          ),
        ),
        // Duration label
        Text(
          _formatDuration(displayDuration),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
