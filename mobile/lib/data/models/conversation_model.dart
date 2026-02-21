import '../../domain/entities/conversation.dart';

class ConversationModel extends Conversation {
  const ConversationModel({
    required super.id,
    required super.name,
    super.avatarUrl,
    super.lastMessage,
    super.lastMessageTime,
    super.lastMessageType,
    super.isOnline,
    super.unreadCount,
    super.isArchived,
    super.isPinned,
    super.isGroup,
    super.hasCheckmark,
    super.voiceNoteDuration,
    super.participantIds,
    super.creatorId,
    super.description,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Chat',
      avatarUrl: json['avatarUrl'] as String?,
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? _parseUtcDateTime(json['lastMessageTime'] as String)
          : null,
      lastMessageType: json['lastMessageType'] != null
          ? MessageType.values.firstWhere(
              (e) => e.toString() == 'MessageType.${json['lastMessageType']}',
              orElse: () => MessageType.text,
            )
          : null,
      isOnline: json['isOnline'] as bool? ?? false,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isArchived: json['isArchived'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      isGroup: json['isGroup'] as bool? ?? false,
      hasCheckmark: json['hasCheckmark'] as bool? ?? false,
      voiceNoteDuration: json['voiceNoteDuration'] != null
          ? Duration(seconds: json['voiceNoteDuration'] as int)
          : null,
      participantIds:
          (json['participantIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      creatorId: json['creatorId'] as String?,
      description: json['description'] as String?,
    );
  }

  static DateTime _parseUtcDateTime(String raw) {
    var str = raw;
    // If no timezone info, treat as UTC
    if (!str.endsWith('Z') && !str.contains('+') && !str.contains('-', 10)) {
      str = '${str}Z';
    }
    return DateTime.tryParse(str)?.toLocal() ?? DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'lastMessageType': lastMessageType?.toString().split('.').last,
      'isOnline': isOnline,
      'unreadCount': unreadCount,
      'isArchived': isArchived,
      'isPinned': isPinned,
      'isGroup': isGroup,
      'hasCheckmark': hasCheckmark,
      'voiceNoteDuration': voiceNoteDuration?.inSeconds,
      'participantIds': participantIds,
      'creatorId': creatorId,
      'description': description,
    };
  }
}
