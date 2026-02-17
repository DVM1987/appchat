import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import 'full_screen_image_viewer.dart';
import 'message_options_sheet.dart';
import 'voice_message_player.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMe;
  final bool isRead;
  final int type; // 0 = Text, 1 = Image, 3 = System, 4 = Voice
  final Function(String name)? onMentionTap;
  final List<String> memberNames; // Added to help match mentions
  final List<dynamic> reactions;
  final Function(String emoji)? onReactionTap;
  final Function()? onReply;
  final Function()? onForward;
  final Function()? onDelete;
  final Function()? onTap;
  final String? replyToContent;
  final String replyToLabel;
  final bool isSelectionMode;
  final bool isForwarded;
  final bool isDeletedMessage;
  final String?
  imageBaseUrl; // Base URL for loading images (defaults to AppConfig.apiBaseUrl)

  const MessageBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
    this.isRead = false,
    this.type = 0,
    this.onMentionTap,
    this.memberNames = const [],
    this.reactions = const [],
    this.onReactionTap,
    this.onReply,
    this.onForward,
    this.onDelete,
    this.onTap,
    this.replyToContent,
    this.replyToLabel = 'Đang trả lời',
    this.isSelectionMode = false,
    this.isForwarded = false,
    this.isDeletedMessage = false,
    this.imageBaseUrl,
  });

  /// Resolve image URL: if relative, prepend base URL
  String _resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final base = imageBaseUrl ?? AppConfig.apiBaseUrl;
    return '$base$url';
  }

  @override
  Widget build(BuildContext context) {
    if (type == 3) {
      return _buildSystemMessage();
    }

    // Image message
    if (type == 1) {
      return _buildImageMessage(context);
    }

    // Voice message
    if (type == 4) {
      return _buildVoiceMessage(context);
    }

    // Colors based on user image (Light Theme)
    final color = isMe ? const Color(0xFFD9FDD3) : Colors.white;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
      bottomRight: isMe ? Radius.zero : const Radius.circular(12),
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        if (!isSelectionMode && !isDeletedMessage) {
          _callShowMessageOptions(context);
        }
      },
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: borderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isForwarded && !isDeletedMessage)
                        _buildForwardedLabel(),
                      if (replyToContent != null && !isDeletedMessage)
                        _buildReplyQuote(),
                      _buildMessageText(),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.done_all,
                              size: 16,
                              color: isRead
                                  ? Colors.blue[900]
                                  : const Color(0xFF25D366),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (reactions.isNotEmpty && !isDeletedMessage)
                  Positioned(
                    bottom: -10,
                    right: isMe ? null : 0,
                    left: isMe ? 0 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _buildReactionSummary(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (reactions.isNotEmpty) const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<Widget> _buildReactionSummary() {
    // Group reactions by type
    final counts = <String, int>{};
    for (var r in reactions) {
      final type = r['type'] ?? r['Type'];
      counts[type] = (counts[type] ?? 0) + 1;
    }

    // Sort by count descending
    final sortedKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    // Take top 3
    final topReactions = sortedKeys.take(3).toList();
    final totalCount = reactions.length;

    final widgets = <Widget>[];
    for (var type in topReactions) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Text(type, style: const TextStyle(fontSize: 12)),
        ),
      );
    }

    if (totalCount > 1) {
      widgets.add(
        Text(
          totalCount.toString(),
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
      );
    }

    return widgets;
  }

  void _callShowMessageOptions(BuildContext rootContext) {
    showMessageOptionsDialog(
      rootContext: rootContext,
      isMe: isMe,
      isForwarded: isForwarded,
      text: text,
      time: time,
      isRead: isRead,
      replyToContent: replyToContent,
      replyToLabel: replyToLabel,
      forwardedLabel: isForwarded ? _buildForwardedLabel(isModal: true) : null,
      onReactionTap: onReactionTap,
      onReply: onReply,
      onForward: onForward,
      onDelete: onDelete,
    );
  }

  Widget _buildMessageText() {
    if (text.isEmpty) return const SizedBox.shrink();

    if (isDeletedMessage) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.block, size: 16, color: Colors.black45),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    final List<TextSpan> spans = [];

    // Build a regex from member names to support multi-word names
    // Sort names by length descending to match longer names first
    final sortedNames = List<String>.from(memberNames)
      ..sort((a, b) => b.length.compareTo(a.length));

    // If we have member names, match them. Also fallback to single-word @mention for safety.
    final String pattern = sortedNames.isEmpty
        ? r'@([^@\s]+)'
        : '@(${sortedNames.map((n) => RegExp.escape(n)).join('|')}|[^@\\s]+)';

    final RegExp mentionRegex = RegExp(pattern);

    int lastMatchEnd = 0;

    for (final Match match in mentionRegex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: const TextStyle(color: Colors.black87),
          ),
        );
      }

      // The match group(0) includes the '@'
      final String mentionFull = match.group(0)!;
      // The name is everything after '@'
      final String mentionName = mentionFull.startsWith('@')
          ? mentionFull.substring(1)
          : mentionFull;

      spans.add(
        TextSpan(
          text: mentionFull,
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (onMentionTap != null) {
                onMentionTap!(mentionName);
              }
            },
        ),
      );

      lastMatchEnd = match.end;
    }

    // Add remaining text
    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: const TextStyle(color: Colors.black87),
        ),
      );
    }

    if (spans.isEmpty) {
      return Text(
        text,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildReplyQuote() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: Colors.blue[400]!, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyToLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          Text(
            replyToContent!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildForwardedLabel({bool isModal = false}) {
    final color = isModal ? Colors.white70 : Colors.black54;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forward, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'Đã chuyển tiếp',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMessage(BuildContext context) {
    final color = isMe ? const Color(0xFFD9FDD3) : Colors.white;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
      bottomRight: isMe ? Radius.zero : const Radius.circular(12),
    );

    final voiceUrl = _resolveImageUrl(text); // same logic: resolve relative URL

    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        if (!isSelectionMode && !isDeletedMessage) {
          _callShowMessageOptions(context);
        }
      },
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
              minWidth: 220,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: borderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isForwarded)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reply,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Chuyển tiếp',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      VoiceMessagePlayer(url: voiceUrl, isMe: isMe),
                      // Time + read status
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                isRead ? Icons.done_all : Icons.done,
                                size: 16,
                                color: isRead ? Colors.blue : Colors.grey,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Reactions
                if (reactions.isNotEmpty && !isDeletedMessage)
                  Positioned(
                    bottom: -10,
                    right: isMe ? null : 0,
                    left: isMe ? 0 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(26),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _buildReactionSummary(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context) {
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
      bottomRight: isMe ? Radius.zero : const Radius.circular(12),
    );

    final imageUrl = _resolveImageUrl(text);

    return GestureDetector(
      onTap:
          onTap ??
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FullScreenImageViewer(imageUrl: imageUrl),
              ),
            );
          },
      onLongPress: () {
        if (!isSelectionMode && !isDeletedMessage) {
          _callShowMessageOptions(context);
        }
      },
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
              maxHeight: 300,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: borderRadius,
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: borderRadius,
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Không tải được ảnh',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // Time overlay at bottom right
                      Positioned(
                        bottom: 4,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.done_all,
                                  size: 14,
                                  color: isRead
                                      ? Colors.blue[300]
                                      : Colors.white70,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Reactions
                if (reactions.isNotEmpty && !isDeletedMessage)
                  Positioned(
                    bottom: -10,
                    right: isMe ? null : 0,
                    left: isMe ? 0 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _buildReactionSummary(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (reactions.isNotEmpty) const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
