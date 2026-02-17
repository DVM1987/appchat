import 'dart:ui';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// Shows the message long-press option dialog (reactions + context menu).
void showMessageOptionsDialog({
  required BuildContext rootContext,
  required bool isMe,
  required bool isForwarded,
  required String text,
  required String time,
  required bool isRead,
  required String? replyToContent,
  required String replyToLabel,
  required Widget? forwardedLabel,
  required Function(String emoji)? onReactionTap,
  required VoidCallback? onReply,
  required VoidCallback? onForward,
  required VoidCallback? onDelete,
}) {
  showGeneralDialog(
    context: rootContext,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

      return Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(dialogContext),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black45),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: align,
                    children: [
                      // 1. Reaction Bar
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B2B2B),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ReactionOption(
                                emoji: '👍',
                                dialogContext: dialogContext,
                                onReactionTap: onReactionTap,
                              ),
                              const SizedBox(width: 12),
                              _ReactionOption(
                                emoji: '❤️',
                                dialogContext: dialogContext,
                                onReactionTap: onReactionTap,
                              ),
                              const SizedBox(width: 12),
                              _ReactionOption(
                                emoji: '😂',
                                dialogContext: dialogContext,
                                onReactionTap: onReactionTap,
                              ),
                              const SizedBox(width: 12),
                              _ReactionOption(
                                emoji: '😮',
                                dialogContext: dialogContext,
                                onReactionTap: onReactionTap,
                              ),
                              const SizedBox(width: 12),
                              _ReactionOption(
                                emoji: '😢',
                                dialogContext: dialogContext,
                                onReactionTap: onReactionTap,
                              ),
                              const SizedBox(width: 12),
                              _ReactionOption(
                                emoji: '🙏',
                                dialogContext: dialogContext,
                                onReactionTap: onReactionTap,
                              ),
                              const SizedBox(width: 12),
                              _ReactionOption(
                                emoji: '👏',
                                dialogContext: dialogContext,
                                onReactionTap: onReactionTap,
                              ),
                              const SizedBox(width: 12),
                              _AddReactionButton(
                                rootContext: rootContext,
                                dialogContext: dialogContext,
                                onReactionTap: onReactionTap,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Message Bubble Preview
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF005C4B)
                              : const Color(0xFF2B2B2B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(dialogContext).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ?forwardedLabel,
                            if (replyToContent != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: const Border(
                                    left: BorderSide(
                                      color: Colors.blue,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      replyToLabel,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    Text(
                                      replyToContent,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Spacer(),
                                Text(
                                  time,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.done_all,
                                    size: 16,
                                    color: isRead
                                        ? Colors.blue[400]
                                        : Colors.white60,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3. Context Menu
                      Container(
                        width: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2B2B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MenuItem(
                              icon: Icons.reply_outlined,
                              text: 'Trả lời',
                              onTap: () => onReply?.call(),
                              dialogContext: dialogContext,
                            ),
                            const Divider(color: Colors.white10, height: 1),
                            _MenuItem(
                              icon: Icons.forward_outlined,
                              text: 'Chuyển tiếp',
                              onTap: () => onForward?.call(),
                              dialogContext: dialogContext,
                            ),
                            const Divider(color: Colors.white10, height: 1),
                            _MenuItem(
                              icon: Icons.content_copy_outlined,
                              text: 'Sao chép',
                              onTap: () {},
                              dialogContext: dialogContext,
                            ),
                            const Divider(color: Colors.white10, height: 1),
                            _MenuItem(
                              icon: Icons.delete_outline,
                              text: 'Xóa',
                              onTap: () => onDelete?.call(),
                              dialogContext: dialogContext,
                              isDestructive: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ── Private helper widgets ──

class _ReactionOption extends StatelessWidget {
  final String emoji;
  final BuildContext dialogContext;
  final Function(String emoji)? onReactionTap;

  const _ReactionOption({
    required this.emoji,
    required this.dialogContext,
    required this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(dialogContext);
        onReactionTap?.call(emoji);
      },
      child: Text(emoji, style: const TextStyle(fontSize: 24)),
    );
  }
}

class _AddReactionButton extends StatelessWidget {
  final BuildContext rootContext;
  final BuildContext dialogContext;
  final Function(String emoji)? onReactionTap;

  const _AddReactionButton({
    required this.rootContext,
    required this.dialogContext,
    required this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(dialogContext).pop();
        _showFullReactionPicker();
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: Colors.grey, size: 20),
      ),
    );
  }

  void _showFullReactionPicker() {
    showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.of(sheetContext).size.height * 0.55,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                Navigator.of(sheetContext).pop();
                onReactionTap?.call(emoji.emoji);
              },
              config: const Config(
                height: 320,
                viewOrderConfig: ViewOrderConfig(
                  top: EmojiPickerItem.searchBar,
                  middle: EmojiPickerItem.emojiView,
                  bottom: EmojiPickerItem.categoryBar,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final BuildContext dialogContext;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.text,
    required this.onTap,
    required this.dialogContext,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(dialogContext);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isDestructive ? Colors.redAccent : Colors.white,
                fontSize: 16,
              ),
            ),
            Icon(
              icon,
              color: isDestructive ? Colors.redAccent : Colors.white70,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
