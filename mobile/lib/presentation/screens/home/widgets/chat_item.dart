import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../domain/entities/conversation.dart';
import '../../chat/forward_message_codec.dart';
import '../../../widgets/common/custom_avatar.dart';

class ChatItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onMore;
  final bool isSelectionMode;
  final bool isSelected;

  const ChatItem({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onArchive,
    this.onMore,
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
                        ), // Adjusted padding
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors
                              .primary, // Or use specific badge color (red?)
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
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 100,
            color: AppColors.surfaceLight,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.more_horiz, color: AppColors.textPrimary),
                SizedBox(height: 4),
                Text(
                  'More',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 100,
            color: AppColors.primary,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.archive, color: AppColors.background),
                SizedBox(height: 4),
                Text(
                  'Archive',
                  style: TextStyle(color: AppColors.background, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
