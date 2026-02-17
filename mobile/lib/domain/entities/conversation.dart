import 'package:equatable/equatable.dart';

enum MessageType { text, photo, voice, video, file }

class Conversation extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final MessageType? lastMessageType;
  final bool isOnline;
  final int unreadCount;
  final bool isArchived;
  final bool isPinned;
  final bool isGroup;
  final bool hasCheckmark; // Message delivered/read status
  final Duration? voiceNoteDuration; // For voice messages
  final List<String> participantIds;

  const Conversation({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageType,
    this.isOnline = false,
    this.unreadCount = 0,
    this.isArchived = false,
    this.isPinned = false,
    this.isGroup = false,
    this.hasCheckmark = false,
    this.voiceNoteDuration,
    this.participantIds = const [],
    this.creatorId,
    this.description,
  });

  final String? creatorId;
  final String? description;

  Conversation copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    MessageType? lastMessageType,
    bool? isOnline,
    int? unreadCount,
    bool? isArchived,
    bool? isPinned,
    bool? isGroup,
    bool? hasCheckmark,
    Duration? voiceNoteDuration,
    List<String>? participantIds,
    String? creatorId,
    String? description,
  }) {
    return Conversation(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      isOnline: isOnline ?? this.isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      isGroup: isGroup ?? this.isGroup,
      hasCheckmark: hasCheckmark ?? this.hasCheckmark,
      voiceNoteDuration: voiceNoteDuration ?? this.voiceNoteDuration,
      participantIds: participantIds ?? this.participantIds,
      creatorId: creatorId ?? this.creatorId,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    avatarUrl,
    lastMessage,
    lastMessageTime,
    lastMessageType,
    isOnline,
    unreadCount,
    isArchived,
    isPinned,
    isGroup,
    hasCheckmark,
    voiceNoteDuration,
    participantIds,
    creatorId,
    description,
  ];
}
