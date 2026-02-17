import 'package:flutter/material.dart';

import '../forward_message_codec.dart';

/// Format a [DateTime] as HH:mm.
String formatTime(DateTime date) {
  return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
}

/// Parse the `createdAt` field from a message map to a local [DateTime].
DateTime parseMessageDate(dynamic message) {
  final raw = message['createdAt'] ?? message['CreatedAt'];
  if (raw is DateTime) return raw.toLocal();
  return DateTime.tryParse(raw?.toString() ?? '')?.toLocal() ?? DateTime.now();
}

/// Extract the message ID from a message map.
String messageIdOf(dynamic message) {
  return (message['id'] ?? message['Id'])?.toString() ?? '';
}

/// Extract the sender ID from a message map.
String messageSenderId(dynamic message) {
  return (message['senderId'] ?? message['SenderId'])?.toString() ?? '';
}

/// Extract the message type as an int from a message map.
int messageType(dynamic message) {
  final raw = message['type'] ?? message['Type'] ?? 0;
  if (raw is int) return raw;
  return int.tryParse(raw.toString()) ?? 0;
}

/// Extract the raw content string from a message map.
String messageRawContent(dynamic message) {
  return (message['content'] ?? message['Content'] ?? '').toString();
}

/// Whether the message has been deleted for everyone.
bool isMessageDeletedForEveryone(dynamic message) {
  final raw =
      message['isDeletedForEveryone'] ?? message['IsDeletedForEveryone'];
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final normalized = raw?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

/// Extract who deleted the message for everyone, if applicable.
String? deletedForEveryoneByUserId(dynamic message) {
  return (message['deletedForEveryoneByUserId'] ??
          message['DeletedForEveryoneByUserId'])
      ?.toString();
}

/// Whether a message is forwarded.
bool isForwardedMessage(dynamic message) {
  return ForwardMessageCodec.isForwarded(messageRawContent(message));
}

/// Get the display content for a message, handling deleted and forwarded
/// messages.
String messageDisplayContent(dynamic message, String? currentUserId) {
  if (isMessageDeletedForEveryone(message)) {
    final current = (currentUserId ?? '').toLowerCase();
    final deletedBy = (deletedForEveryoneByUserId(message) ?? '').toLowerCase();
    final senderId = messageSenderId(message).toLowerCase();

    final deletedByMe =
        (current.isNotEmpty && deletedBy == current) ||
        (deletedBy.isEmpty && current.isNotEmpty && senderId == current);

    return deletedByMe ? 'Bạn đã xoá tin nhắn này.' : 'Tin nhắn này đã bị xoá.';
  }
  return ForwardMessageCodec.decode(messageRawContent(message));
}

/// Get the display content for a reply-to message.
String? messageReplyDisplayContent(dynamic message) {
  final raw = (message['replyToContent'] ?? message['ReplyToContent'])
      ?.toString();
  if (raw == null) return null;
  return ForwardMessageCodec.decode(raw);
}

/// Extract the readBy list from a message map.
List<dynamic> messageReadBy(dynamic message) {
  final readBy = message['readBy'] ?? message['ReadBy'];
  if (readBy is List) return List<dynamic>.from(readBy);
  return <dynamic>[];
}

/// Whether the current user has read the message.
bool isMessageReadByCurrentUser(dynamic message, String? currentUserId) {
  if (currentUserId == null) return false;
  return messageReadBy(
    message,
  ).any((id) => id.toString().toLowerCase() == currentUserId.toLowerCase());
}

/// Whether the message is an unread incoming message.
bool isUnreadIncomingMessage(dynamic message, String? currentUserId) {
  final senderId = messageSenderId(message);
  if (currentUserId == null || senderId.isEmpty) return false;
  if (senderId.toLowerCase() == currentUserId.toLowerCase()) return false;
  return !isMessageReadByCurrentUser(message, currentUserId);
}

/// Whether to show a date divider before this message.
bool shouldShowDateDivider(int index, DateTime date, List<dynamic> messages) {
  if (messages.isEmpty) return false;
  if (index == messages.length - 1) return true;
  final olderMessageDate = parseMessageDate(messages[index + 1]);
  return !DateUtils.isSameDay(date, olderMessageDate);
}

/// Format a date as a human-readable day label.
String formatDayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(date.year, date.month, date.day);
  final diffDays = today.difference(messageDay).inDays;

  if (diffDays == 0) return 'Hôm nay';
  if (diffDays == 1) return 'Hôm qua';

  final day = messageDay.day.toString().padLeft(2, '0');
  final month = messageDay.month.toString().padLeft(2, '0');
  final year = messageDay.year.toString();
  return '$day/$month/$year';
}

/// Format a relative time ago string.
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return "vừa xong";
  if (diff.inMinutes < 60) return "${diff.inMinutes} phút trước";
  if (diff.inHours < 24) return "${diff.inHours} giờ trước";
  return formatTime(d);
}

/// Resolve display name for a user ID given group member profiles.
String resolveDisplayNameForUserId(
  String? userId, {
  required String? currentUserId,
  required bool isGroup,
  required String otherUserName,
  required List<Map<String, dynamic>> groupMemberProfiles,
}) {
  if (userId == null || userId.isEmpty) return 'Người dùng';
  if (currentUserId != null &&
      userId.toLowerCase() == currentUserId.toLowerCase()) {
    return 'You';
  }

  if (!isGroup) {
    return otherUserName;
  }

  for (final member in groupMemberProfiles) {
    final candidateId =
        (member['identityId'] ??
                member['IdentityId'] ??
                member['id'] ??
                member['Id'])
            ?.toString();
    if (candidateId != null &&
        candidateId.isNotEmpty &&
        candidateId.toLowerCase() == userId.toLowerCase()) {
      final name = (member['fullName'] ?? member['FullName'])
          ?.toString()
          .trim();
      if (name != null && name.isNotEmpty) return name;
    }
  }

  return 'Người dùng';
}

/// Resolve group avatar URL for a user ID.
String? resolveGroupAvatarUrl(
  String? userId,
  List<Map<String, dynamic>> groupMemberProfiles,
) {
  if (userId == null || userId.isEmpty) return null;

  for (final member in groupMemberProfiles) {
    final candidateId =
        (member['identityId'] ??
                member['IdentityId'] ??
                member['id'] ??
                member['Id'])
            ?.toString();
    if (candidateId != null &&
        candidateId.isNotEmpty &&
        candidateId.toLowerCase() == userId.toLowerCase()) {
      final avatar = (member['avatarUrl'] ?? member['AvatarUrl'])
          ?.toString()
          .trim();
      if (avatar != null && avatar.isNotEmpty) {
        return avatar;
      }
      return null;
    }
  }

  return null;
}
