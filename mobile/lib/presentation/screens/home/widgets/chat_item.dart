import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../domain/entities/conversation.dart';
import '../../../widgets/common/custom_avatar.dart';
import '../../chat/forward_message_codec.dart';

class ChatItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onMore;
  final VoidCallback? onDelete;
  final bool isSelectionMode;
  final bool isSelected;

  const ChatItem({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onArchive,
    this.onMore,
    this.onDelete,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(conversation.id),
      direction: isSelectionMode
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Show confirmation dialog before deleting
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text(
                  'Xóa cuộc trò chuyện?',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                content: Text(
                  'Cuộc trò chuyện với "${conversation.name}" sẽ bị xóa vĩnh viễn và không thể khôi phục.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Hủy'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Xóa'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        onDelete?.call();
      },
      background: _buildSwipeBackground(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Checkbox (only in selection mode)
              if (isSelectionMode) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.iconSecondary,
                      width: 2,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: AppColors.background,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
              ],

              // Avatar
              CustomAvatar(
                imageUrl: conversation.avatarUrl,
                name: conversation.name,
                size: 60,
                showOnlineIndicator: !isSelectionMode,
                isOnline: conversation.isOnline,
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      conversation.name,
                      style: AppTextStyles.chatName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Last Message
                    _buildLastMessage(),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Time & Chevron (hide chevron in selection mode)
              // Time & Unread Badge
              if (!isSelectionMode)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (conversation.lastMessageTime != null)
                      Text(
                        DateFormatter.formatChatTimestamp(
                          conversation.lastMessageTime!,
                        ),
                        style: conversation.unreadCount > 0
                            ? AppTextStyles.chatTime.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              )
                            : AppTextStyles.chatTime,
                      ),
                    const SizedBox(height: 6),
                    if (conversation.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          conversation.unreadCount > 99
                              ? '99+'
                              : '${conversation.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                  ],
                ),

              // Just time in selection mode
              if (isSelectionMode && conversation.lastMessageTime != null)
                Text(
                  DateFormatter.formatChatTimestamp(
                    conversation.lastMessageTime!,
                  ),
                  style: AppTextStyles.chatTime,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastMessage() {
    final rawLastMessage = conversation.lastMessage ?? '';
    final isForwarded = ForwardMessageCodec.isForwarded(rawLastMessage);
    final displayLastMessage = ForwardMessageCodec.decode(rawLastMessage);

    // Voice note
    if (conversation.lastMessageType == MessageType.voice &&
        conversation.voiceNoteDuration != null) {
      return Row(
        children: [
          const Icon(Icons.mic, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            DateFormatter.formatDuration(conversation.voiceNoteDuration!),
            style: AppTextStyles.chatMessage,
          ),
        ],
      );
    }

    // Photo
    if (conversation.lastMessageType == MessageType.photo) {
      return Row(
        children: [
          const Icon(Icons.photo, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            conversation.lastMessage ?? 'Photo',
            style: AppTextStyles.chatMessage,
          ),
        ],
      );
    }

    // Text message
    return Row(
      children: [
        if (conversation.hasCheckmark)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(
              Icons.done_all,
              size: 16,
              color: AppColors.messageDelivered,
            ),
          ),
        Expanded(
          child: Text(
            isForwarded
                ? 'Đã chuyển tiếp: $displayLastMessage'
                : displayLastMessage,
            style: AppTextStyles.chatMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeBackground() {
    return Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_forever, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text(
            'Xóa',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
