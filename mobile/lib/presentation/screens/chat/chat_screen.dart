import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/chat_service.dart';
import '../../../../data/services/user_service.dart';
import '../../widgets/common/custom_avatar.dart';
import '../call/call_screen.dart';
import '../group/group_invite_screen.dart';
import '../group/group_members_screen.dart';
import '../group/new_group_select_members_screen.dart';
import '../profile/profile_screen.dart';
import 'forward_recipients_screen.dart';
import 'widgets/chat_decorations.dart';
import 'widgets/chat_input.dart';
import 'widgets/chat_message_helpers.dart' as helpers;
import 'widgets/chat_selection_bars.dart';
import 'widgets/group_admin_dashboard.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String chatId; // This is FriendId OR ConversationId (if isGroup)
  final String otherUserName;
  final String? otherUserAvatar;
  final bool isGroup;
  final String? creatorId;
  final List<String>? participantIds;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.isGroup = false,
    this.creatorId,
    this.participantIds,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  String? _conversationId;
  String? _currentUserId;
  String? _inviteToken;
  String? _creatorId;
  // Using dynamic for now, should use Message Entity
  final List<dynamic> _messages = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  // Group Info State
  List<String> _currentParticipantIds = [];
  List<Map<String, dynamic>> _groupMemberProfiles = [];
  String _groupName = '';
  // Presence & Typing State
  bool _isOtherUserOnline = false;
  bool _isOtherUserTyping = false;
  String? _typingUserName;
  DateTime? _lastSeen;
  Timer? _typingTimer;
  Timer? _typingThrottleTimer;
  Timer? _offlineTimer;
  Timer? _incomingSyncTimer;
  Timer? _unreadDividerTimer;
  bool _hasReceivedPresenceUpdate = false; // Track if we got a real-time update

  // Reply state
  Map<String, dynamic>? _replyToMessage;
  String? _unreadDividerMessageId;
  bool _showUnreadDivider = false;
  bool _isForwardSelectionMode = false;
  final Set<String> _forwardSelectedMessageIds = <String>{};
  bool _isDeleteSelectionMode = false;
  final Set<String> _deleteSelectedMessageIds = <String>{};

  // Cleanup subscriptions
  final List<StreamSubscription> _subscriptions = [];

  Timer? _presencePollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentParticipantIds = List.from(widget.participantIds ?? []);
    _creatorId = widget.creatorId;
    _groupName = widget.otherUserName;
    _initChat();

    // Polling fallback: Check presence every 10s if we think they are offline
    // This handles cases where we missed the UserOnline event
    _presencePollingTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) {
      if (!_isOtherUserOnline &&
          !widget.isGroup &&
          mounted &&
          _conversationId != null) {
        _fetchInitialPresence(force: true);
      }
    });
  }

  Future<void> _initChat() async {
    try {
      AppConfig.log(
        'InitChat for chatId: ${widget.chatId}, isGroup: ${widget.isGroup}',
      );
      _currentUserId = await AuthService.getUserId();

      // Ensure SignalR is initialized/connected first with latest token
      await _chatService.initSignalR();

      if (widget.isGroup) {
        _conversationId = widget.chatId;
        // Fetch additional details (like inviteToken, creatorId)
        _chatService.getConversationDetails(_conversationId!).then((details) {
          if (details != null && mounted) {
            setState(() {
              _inviteToken = details['inviteToken'];
              _creatorId = details['creatorId'];
            });
          }
        });
      } else {
        // Chat 1-1: chatId is FriendId
        _conversationId = await _chatService.createConversation(widget.chatId);
      }

      if (mounted) {
        setState(
          () {},
        ); // Trigger rebuild to update _conversationId dependent UI
      }

      // 2. Load History
      final history = await _chatService.getMessages(_conversationId!);
      _prepareUnreadDividerFromMessages(history);

      // 3. Join Conversation Channel
      await _chatService.joinConversation(_conversationId!);
      // Mark as read immediately
      await _markConversationAsRead();

      // 4. Setup Listeners
      _setupSignalRListeners();

      // 5. Get Initial Presence (Chat 1-1 only)
      if (!widget.isGroup) {
        _fetchInitialPresence();
      }

      // 6. Fetch Group Member Profiles (for mentions)
      if (widget.isGroup) {
        _fetchGroupMemberProfiles();
      }

      if (mounted) {
        setState(() {
          _messages.clear(); // Clear old data if any
          _messages.addAll(history);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppConfig.log('Chat connection error: $e');
        // Retry logic or show error
      }
    }
  }

  void _setupSignalRListeners() {
    // Message Reacted Listener
    _subscriptions.add(
      _chatService.messageReactedStream.listen((data) {
        if (!mounted) return;

        AppConfig.log('ChatScreen: Received reaction event: $data');

        final conversationId = data['conversationId'] ?? data['ConversationId'];
        if (conversationId != _conversationId) return;

        final messageId = data['messageId'] ?? data['MessageId'];
        final userId = data['userId'] ?? data['UserId'];
        final reactionType = data['reactionType'] ?? data['ReactionType'];

        setState(() {
          final index = _messages.indexWhere(
            (m) => (m['id'] ?? m['Id']).toString() == messageId.toString(),
          );

          if (index != -1) {
            // Clone to avoid direct mutation issues
            final message = Map<String, dynamic>.from(_messages[index]);

            // Handle both casing for initial load (GetMessages) vs signalR updates
            List<dynamic> reactions = [];
            if (message['reactions'] != null) {
              reactions = List<dynamic>.from(message['reactions']);
            } else if (message['Reactions'] != null) {
              reactions = List<dynamic>.from(message['Reactions']);
            }

            // Check if user already reacted
            final existingIndex = reactions.indexWhere((r) {
              final rUserId = r['userId'] ?? r['UserId'];
              return rUserId.toString() == userId.toString();
            });

            if (existingIndex != -1) {
              final existingType =
                  (reactions[existingIndex]['type'] ??
                          reactions[existingIndex]['Type'])
                      .toString();
              if (existingType == reactionType) {
                // Toggle off if same
                reactions.removeAt(existingIndex);
              } else {
                // Update if different
                reactions[existingIndex] = {
                  'userId': userId,
                  'type': reactionType,
                  'reactedAt': DateTime.now().toIso8601String(),
                };
              }
            } else {
              // Add new
              reactions.add({
                'userId': userId,
                'type': reactionType,
                'reactedAt': DateTime.now().toIso8601String(),
              });
            }

            // Update both to be safe
            message['reactions'] = reactions;
            message['Reactions'] = reactions;

            // CRITICAL: Replace the item in the list with the cloned and updated map
            _messages[index] = message;
          }
        });
      }),
    );

    // Message Deleted Listener
    _subscriptions.add(
      _chatService.messageDeletedStream.listen((data) {
        if (!mounted) return;
        final conversationId = data['conversationId']?.toString();
        final messageId = data['messageId']?.toString();
        final scope = data['scope']?.toString().toLowerCase();
        final deletedByUserId = data['userId']?.toString();
        if (conversationId != _conversationId ||
            messageId == null ||
            messageId.isEmpty) {
          return;
        }

        if (scope == 'everyone') {
          _markMessageDeletedForEveryoneLocally(
            messageId,
            deletedByUserId: deletedByUserId,
          );
        } else {
          _removeMessageLocally(messageId);
        }
      }),
    );

    // Message Listener
    _subscriptions.add(
      _chatService.messageStream.listen((message) {
        if (!mounted) return;

        final normalizedMessage = _normalizeIncomingMessage(message);
        final msgConvId = normalizedMessage['conversationId'];
        // Strict check: Only show messages for THIS conversation
        if (msgConvId != _conversationId) return;

        final messageId = normalizedMessage['id'];
        if (messageId is! String || messageId.isEmpty) {
          // Payload realtime không đủ dữ liệu: fallback sync lại list message
          _scheduleIncomingSync();
          return;
        }

        setState(() {
          // Check for duplicates
          final index = _messages.indexWhere(
            (m) => (m['id'] ?? m['Id']) == messageId,
          );
          if (index == -1) {
            _messages.insert(0, normalizedMessage);
          } else {
            _messages[index] = normalizedMessage;
          }
        });

        // Auto mark as read if message is from other
        final senderId = normalizedMessage['senderId'];
        if (senderId != _currentUserId) {
          unawaited(_markConversationAsRead());
          // Sync lại để đảm bảo quote/reaction luôn cập nhật đủ phía user nhận
          _scheduleIncomingSync();
        }

        final replyToId = normalizedMessage['replyToId']?.toString();
        final replyToContent = normalizedMessage['replyToContent']?.toString();
        final isReply = replyToId != null && replyToId.isNotEmpty;
        final missingReplyQuote =
            isReply &&
            (replyToContent == null || replyToContent.trim().isEmpty);
        if (missingReplyQuote) {
          // Một số payload realtime có thể thiếu quote content -> sync lại để hiện ngay
          _scheduleIncomingSync();
        }
      }),
    );

    // Typing Listener
    _subscriptions.add(
      _chatService.userTypingStream.listen((data) {
        if (!mounted) return;

        final conversationId = data['conversationId'];
        final userId = data['userId'];
        final userName = data['userName'] ?? 'Ai đó';

        // Check if typing event belongs to this conversation AND is not me
        if (conversationId == _conversationId && userId != _currentUserId) {
          setState(() {
            _isOtherUserTyping = true;
            _typingUserName = userName;
          });

          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isOtherUserTyping = false;
                _typingUserName = null;
              });
            }
          });
        }
      }),
    );

    // Online Listener
    _subscriptions.add(
      _chatService.userOnlineStream.listen((userId) {
        if (!mounted) return;
        if (!widget.isGroup &&
            userId.toLowerCase() == widget.chatId.toLowerCase()) {
          // Cancel any pending offline timer to prevent flickering
          if (_offlineTimer?.isActive ?? false) {
            _offlineTimer!.cancel();
            AppConfig.log(
              'ChatScreen: Cancelled pending offline update due to re-online event',
            );
          }

          // Set flag to prevent _fetchInitialPresence from overwriting
          _hasReceivedPresenceUpdate = true;
          setState(() {
            _isOtherUserOnline = true;
          });
        }
      }),
    );

    // Offline Listener
    _subscriptions.add(
      _chatService.userOfflineStream.listen((userId) {
        if (!mounted) return;
        if (!widget.isGroup &&
            userId.toLowerCase() == widget.chatId.toLowerCase()) {
          // Set flag
          _hasReceivedPresenceUpdate = true;
          // Debounce the offline status update by 3 seconds
          _offlineTimer?.cancel();
          _offlineTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isOtherUserOnline = false;
                _lastSeen = DateTime.now();
              });
            }
          });
        }
      }),
    );

    // Read Listener
    _subscriptions.add(
      _chatService.messageReadStream.listen((data) {
        final conversationId = data['conversationId'];
        final userId = data['userId']; // User who read the messages

        AppConfig.log(
          'SignalR: MessagesRead event: Conv=$conversationId, User=$userId',
        );

        if (conversationId == _conversationId &&
            mounted &&
            userId != _currentUserId) {
          setState(() {
            // Mark all my messages as read by this user
            for (var i = 0; i < _messages.length; i++) {
              // Assuming 'readBy' is a List<String> of userIds
              List<dynamic> readBy = _messages[i]['readBy'] ?? [];
              if (!readBy.contains(userId)) {
                // We need to clone to avoid mutating state directly if possible, or just update
                // Since _messages is a List<dynamic> (Maps), we can mutate the map inside.
                final newReadBy = List<dynamic>.from(readBy)..add(userId);
                _messages[i]['readBy'] = newReadBy;
              }
            }
          });
        }
      }),
    );

    // Conversation Updated Listener
    _subscriptions.add(
      _chatService.conversationUpdatedStream.listen((data) {
        AppConfig.log(
          'SignalR: ConversationUpdated received in ChatScreen: $data',
        );
        if (data is Map<String, dynamic> &&
            data['id'] == _conversationId &&
            mounted) {
          setState(() {
            if (data['name'] != null) {
              _groupName = data['name'];
            }
            if (data['participantIds'] != null) {
              _currentParticipantIds = (data['participantIds'] as List<dynamic>)
                  .map((e) => e.toString())
                  .toList();
              AppConfig.log(
                'Updated local participant list: ${_currentParticipantIds.length}',
              );
              _inviteToken = data['inviteToken'];
              _fetchGroupMemberProfiles(); // Refresh profiles for mentions
            }
          });

          // Check if I am still in the group
          if (_currentUserId != null &&
              !_currentParticipantIds.contains(_currentUserId)) {
            AppConfig.log('I have been removed from the group. Popping.');
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bạn đã không còn là thành viên nhóm'),
              ),
            );
          }
        }
      }),
    );

    // Conversation Deleted Listener
    _subscriptions.add(
      _chatService.conversationDeletedStream.listen((deletedId) {
        if (deletedId == _conversationId && mounted) {
          AppConfig.log('Conversation $deletedId deleted. Popping ChatScreen.');
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Nhóm đã bị giải tán')));
        }
      }),
    );
  }

  Future<void> _fetchGroupMemberProfiles() async {
    AppConfig.log(
      'ChatScreen: _fetchGroupMemberProfiles called for ids: $_currentParticipantIds',
    );
    final List<Map<String, dynamic>> profiles = [];
    final userService = UserService();

    for (var id in _currentParticipantIds) {
      // In groups, we often want to be able to tag ourselves too (@all or just me)
      // but usually apps skip the current user. Let's include everyone for now to test.
      try {
        final profile = await userService.getUserProfile(id);
        if (profile != null) {
          profiles.add(profile);
          AppConfig.log(
            'ChatScreen: Added profile for mention: ${profile['fullName']}',
          );
        }
      } catch (e) {
        AppConfig.log('Error fetching profile for $id: $e');
      }
    }

    if (mounted) {
      setState(() {
        _groupMemberProfiles = profiles;
        AppConfig.log(
          'ChatScreen: _groupMemberProfiles updated, count: ${_groupMemberProfiles.length}',
        );
      });
    }
  }

  Future<void> _fetchInitialPresence({bool force = false}) async {
    if (widget.isGroup) return;

    try {
      final presence = await _chatService.getPresence(widget.chatId);
      if (presence != null && mounted) {
        // If we already received a realtime update, don't overwrite with potentially stale snapshot
        // Unless forced (e.g. by polling or resume)
        if (_hasReceivedPresenceUpdate && !force) {
          AppConfig.log(
            'Skipping initial presence snapshot deeply due to realtime update',
          );
          return;
        }

        final status = presence['status'].toString();
        final isOnline = (status == 'Online' || status == '1');

        setState(() {
          _isOtherUserOnline = isOnline;
          if (presence['lastSeen'] != null) {
            _lastSeen = DateTime.tryParse(presence['lastSeen'].toString());
          }
        });

        // Retry logic: If offline but we suspect race condition (e.g. just Resumed), fetch again shortly
        if (!isOnline && !force) {
          Future.delayed(const Duration(seconds: 2), () async {
            if (mounted && !_hasReceivedPresenceUpdate && !_isOtherUserOnline) {
              AppConfig.log('Retrying presence fetch...');
              _fetchInitialPresence(force: true);
            }
          });
        }
      }
    } catch (e) {
      AppConfig.log('Error fetching presence: $e');
    }
  }

  Future<void> _handleSend(
    String text, {
    String? replyToId,
    String? replyToContent,
  }) async {
    if (_conversationId == null) return;
    final isReplyMessage =
        (replyToId != null && replyToId.isNotEmpty) ||
        (replyToContent != null && replyToContent.isNotEmpty);
    try {
      await _chatService.sendMessage(
        _conversationId!,
        text,
        replyToId: replyToId,
        replyToContent: replyToContent,
      );

      if (mounted && _replyToMessage != null) {
        setState(() {
          _replyToMessage = null;
        });
      }

      // Fallback for reply messages: ensure UI reflects quote content immediately
      // even if realtime payload arrives with inconsistent casing/shape.
      if (isReplyMessage) {
        await _refreshMessages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi tin nhắn thất bại: $e')));
      }
    }
  }

  Future<void> _handleSendImages(List<File> imageFiles) async {
    if (_conversationId == null) return;
    try {
      await _chatService.sendImageMessages(_conversationId!, imageFiles);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi ảnh thất bại: $e')));
      }
    }
  }

  Future<void> _handleSendVoice(File voiceFile) async {
    if (_conversationId == null) return;
    try {
      AppConfig.log(
        'Voice: sending file ${voiceFile.path}, exists: ${await voiceFile.exists()}, size: ${await voiceFile.length()} bytes',
      );
      await _chatService.sendVoiceMessage(_conversationId!, voiceFile);
      AppConfig.log('Voice: sent successfully');
    } catch (e, stackTrace) {
      AppConfig.log('Voice: send failed: $e');
      AppConfig.log('Voice: stackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi voice thất bại: $e')));
      }
    }
  }

  void _handleTyping() {
    if (_conversationId == null) return;
    if (_typingThrottleTimer?.isActive ?? false) return;

    _chatService.sendTyping(_conversationId!);
    _typingThrottleTimer = Timer(const Duration(seconds: 2), () {});
  }

  Future<void> _openGroupMembers() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMembersScreen(
          conversationId: _conversationId!,
          members: _groupMemberProfiles,
          creatorId: _creatorId,
          isAdmin: _isAdmin,
          onMembersUpdated: (updatedProfiles) {
            setState(() {
              _groupMemberProfiles = updatedProfiles;
            });
          },
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context); // Close ChatScreen because we left the group
    }
  }

  Future<void> _showEditGroupDialog() async {
    final nameController = TextEditingController(text: _groupName);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên nhóm'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Tên nhóm mới'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty || newName == _groupName) {
                Navigator.pop(context);
                return;
              }
              try {
                await _chatService.updateConversation(
                  _conversationId!,
                  newName,
                  null,
                  null,
                );
                // Optimistic UI update, though SignalR will handle it
                if (context.mounted) {
                  setState(() {
                    _groupName = newName;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã cập nhật tên nhóm')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _disbandGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Giải tán nhóm'),
        content: const Text(
          'Bạn có chắc chắn muốn giải tán nhóm này? Tất cả tin nhắn sẽ bị xóa vĩnh viễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Giải tán'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _chatService.disbandConversation(_conversationId!);
        // SignalR will handle popping the screen
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    _typingThrottleTimer?.cancel();
    _presencePollingTimer?.cancel();
    _incomingSyncTimer?.cancel();
    _unreadDividerTimer?.cancel();
    _scrollController.dispose();
    for (var s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh presence after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          AppConfig.log(
            'App Resumed: Refreshing presence for ${widget.chatId}',
          );
          _hasReceivedPresenceUpdate = false; // Reset flag to allow fresh fetch
          _fetchInitialPresence();
          _refreshMessages(); // Sync missed messages
          if (_conversationId != null) {
            unawaited(_markConversationAsRead());
          }
        }
      });
    }
  }

  Future<void> _refreshMessages() async {
    if (_conversationId == null) return;
    try {
      final latest = await _chatService.getMessages(_conversationId!);
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(latest);
          _syncUnreadDividerWithCurrentMessages();
        });
      }
    } catch (e) {
      AppConfig.log('Failed to refresh messages: $e');
    }
  }

  Future<void> _markConversationAsRead() async {
    if (_conversationId == null) return;
    await _chatService.markAsRead(_conversationId!);
    _scheduleUnreadDividerAutoHideIfNeeded();
  }

  void _scheduleIncomingSync() {
    _incomingSyncTimer?.cancel();
    _incomingSyncTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _refreshMessages();
    });
  }

  void _prepareUnreadDividerFromMessages(List<dynamic> sourceMessages) {
    if (_currentUserId == null) return;
    int? oldestUnreadIndex;

    for (var i = 0; i < sourceMessages.length; i++) {
      if (_isUnreadIncomingMessage(sourceMessages[i])) {
        oldestUnreadIndex = i;
      }
    }

    if (oldestUnreadIndex == null) {
      _unreadDividerMessageId = null;
      _showUnreadDivider = false;
      return;
    }

    final markerId = _messageIdOf(sourceMessages[oldestUnreadIndex]);
    if (markerId.isEmpty) {
      _unreadDividerMessageId = null;
      _showUnreadDivider = false;
      return;
    }

    _unreadDividerMessageId = markerId;
    _showUnreadDivider = true;
  }

  void _scheduleUnreadDividerAutoHideIfNeeded() {
    if (!_showUnreadDivider || _unreadDividerMessageId == null) return;

    _unreadDividerTimer?.cancel();
    _unreadDividerTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _showUnreadDivider = false;
        _unreadDividerMessageId = null;
      });
    });
  }

  void _syncUnreadDividerWithCurrentMessages() {
    if (!_showUnreadDivider || _unreadDividerMessageId == null) return;

    final stillExists = _messages.any(
      (m) => _messageIdOf(m) == _unreadDividerMessageId,
    );
    if (!stillExists) {
      _unreadDividerMessageId = null;
      _showUnreadDivider = false;
      _unreadDividerTimer?.cancel();
    }
  }

  Map<String, dynamic> _normalizeIncomingMessage(dynamic raw) {
    dynamic payload = raw;
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (_) {
        payload = <String, dynamic>{};
      }
    }

    final map = payload is Map
        ? payload.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    dynamic readValue(List<String> candidates) {
      for (final key in candidates) {
        if (map.containsKey(key)) return map[key];
      }

      final lowerCandidates = candidates.map((k) => k.toLowerCase()).toSet();
      for (final entry in map.entries) {
        if (lowerCandidates.contains(entry.key.toString().toLowerCase())) {
          return entry.value;
        }
      }
      return null;
    }

    final senderId = readValue(['senderId', 'SenderId'])?.toString() ?? '';
    final readBy = readValue(['readBy', 'ReadBy']);
    final normalizedReadBy = (readBy is List)
        ? List<dynamic>.from(readBy)
        : <dynamic>[if (senderId.isNotEmpty) senderId];

    return {
      'id': readValue(['id', 'Id'])?.toString() ?? '',
      'conversationId':
          readValue(['conversationId', 'ConversationId'])?.toString() ?? '',
      'senderId': senderId,
      'content': readValue(['content', 'Content'])?.toString() ?? '',
      'type': readValue(['type', 'Type']) ?? 0,
      'createdAt':
          readValue(['createdAt', 'CreatedAt'])?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      'replyToId': readValue(['replyToId', 'ReplyToId'])?.toString(),
      'replyToContent': readValue([
        'replyToContent',
        'ReplyToContent',
      ])?.toString(),
      'readBy': normalizedReadBy,
      'reactions': readValue(['reactions', 'Reactions']) is List
          ? List<dynamic>.from(readValue(['reactions', 'Reactions']) as List)
          : <dynamic>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leadingWidth: 70,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.arrow_back, color: Colors.black),
              const SizedBox(width: 4),
              CustomAvatar(
                imageUrl: widget.otherUserAvatar,
                name: widget.isGroup ? _groupName : widget.otherUserName,
                size: 36,
                showOnlineIndicator: true,
                isOnline: _isOtherUserOnline,
              ),
            ],
          ),
        ),
        title: InkWell(
          onTap: widget.isGroup ? _openGroupMembers : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isGroup ? _groupName : widget.otherUserName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.isGroup)
                Text(
                  '${_currentParticipantIds.length} thành viên',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                )
              else if (_isOtherUserOnline)
                const Text(
                  'Đang hoạt động',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                )
              else if (_lastSeen != null)
                Text(
                  'Truy cập ${_timeAgo(_lastSeen!)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                )
              else
                const SizedBox(height: 0),
            ],
          ),
        ),
        actions: (_isForwardSelectionMode || _isDeleteSelectionMode)
            ? [
                TextButton(
                  onPressed: _cancelSelectionMode,
                  child: const Text(
                    'Hủy',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(
                    Icons.videocam_outlined,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          calleeName: widget.isGroup
                              ? _groupName
                              : widget.otherUserName,
                          calleeAvatar: widget.otherUserAvatar,
                          callType: CallType.video,
                          otherUserId: widget.chatId,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.call_outlined, color: Colors.black),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          calleeName: widget.isGroup
                              ? _groupName
                              : widget.otherUserName,
                          calleeAvatar: widget.otherUserAvatar,
                          callType: CallType.audio,
                          otherUserId: widget.chatId,
                        ),
                      ),
                    );
                  },
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true, // Start from bottom
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildStartOfChat();
                      }

                      final message = _messages[index];
                      final isMe = _messageSenderId(message) == _currentUserId;
                      final isDeletedForEveryone = _isMessageDeletedForEveryone(
                        message,
                      );
                      final date = _parseMessageDate(message);
                      final displayContent = _messageDisplayContent(message);
                      final isForwarded = _isForwardedMessage(message);
                      final shouldShowDateDivider = _shouldShowDateDivider(
                        index,
                        date,
                      );
                      final shouldShowUnreadDivider = _shouldShowUnreadDivider(
                        message,
                      );
                      final shouldShowGroupSenderAvatar =
                          widget.isGroup &&
                          !isMe &&
                          _messageType(message) != 3 &&
                          !_isForwardSelectionMode &&
                          !_isDeleteSelectionMode;

                      Widget messageWidget = MessageBubble(
                        text: displayContent,
                        time: _formatTime(date),
                        isMe: isMe,
                        isRead: _messageReadBy(message).length > 1,
                        type: _messageType(message),
                        isForwarded: isDeletedForEveryone ? false : isForwarded,
                        isDeletedMessage: isDeletedForEveryone,
                        memberNames: _groupMemberProfiles
                            .map(
                              (m) => (m['fullName'] ?? m['FullName'] ?? '')
                                  .toString(),
                            )
                            .where((name) => name.isNotEmpty)
                            .toList(),
                        reactions: isDeletedForEveryone
                            ? const []
                            : (message['reactions'] ?? []),
                        onReactionTap: isDeletedForEveryone
                            ? null
                            : (emoji) {
                                _chatService.reactToMessage(
                                  _conversationId!,
                                  message['id'] ?? message['Id'],
                                  emoji,
                                );
                              },
                        onReply: isDeletedForEveryone
                            ? null
                            : () {
                                setState(() {
                                  _replyToMessage = message;
                                });
                              },
                        onForward: isDeletedForEveryone
                            ? null
                            : () {
                                _enterForwardSelectionMode(message);
                              },
                        onDelete: isDeletedForEveryone
                            ? null
                            : () {
                                _enterDeleteSelectionMode(message);
                              },
                        onTap: _isForwardSelectionMode
                            ? () {
                                _toggleForwardMessageSelection(message);
                              }
                            : (_isDeleteSelectionMode
                                  ? () {
                                      _toggleDeleteMessageSelection(message);
                                    }
                                  : null),
                        isSelectionMode:
                            _isForwardSelectionMode || _isDeleteSelectionMode,
                        replyToContent: isDeletedForEveryone
                            ? null
                            : _messageReplyDisplayContent(message),
                        replyToLabel: _resolveReplyToLabel(message),
                        onMentionTap: (name) {
                          final member = _groupMemberProfiles.firstWhere(
                            (m) =>
                                (m['fullName'] ?? m['FullName'] ?? '')
                                    .toString()
                                    .toLowerCase() ==
                                name.toLowerCase(),
                            orElse: () => {},
                          );
                          if (member.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId: member['id'] ?? member['Id'],
                                ),
                              ),
                            );
                          }
                        },
                      );

                      if ((_isForwardSelectionMode || _isDeleteSelectionMode) &&
                          !isDeletedForEveryone) {
                        final isSelected = _isForwardSelectionMode
                            ? _forwardSelectedMessageIds.contains(
                                _messageIdOf(message),
                              )
                            : _deleteSelectedMessageIds.contains(
                                _messageIdOf(message),
                              );
                        messageWidget = Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, right: 4),
                              child: GestureDetector(
                                onTap: () {
                                  if (_isForwardSelectionMode) {
                                    _toggleForwardMessageSelection(message);
                                  } else {
                                    _toggleDeleteMessageSelection(message);
                                  }
                                },
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? const Color(0xFF25D366)
                                      : Colors.grey[500],
                                  size: 30,
                                ),
                              ),
                            ),
                            Expanded(child: messageWidget),
                          ],
                        );
                      }

                      if (shouldShowGroupSenderAvatar) {
                        final senderId = _messageSenderId(message);
                        final senderName = _resolveDisplayNameForUserId(
                          senderId,
                        );
                        final senderAvatarUrl = _resolveGroupAvatarUrl(
                          senderId,
                        );

                        messageWidget = Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 6,
                                right: 2,
                                bottom: 8,
                              ),
                              child: CustomAvatar(
                                imageUrl: senderAvatarUrl,
                                name: senderName,
                                size: 28,
                              ),
                            ),
                            Expanded(child: messageWidget),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (shouldShowDateDivider) ...[
                            DateDivider(date: _formatDayLabel(date)),
                            const SizedBox(height: 8),
                          ],
                          if (shouldShowUnreadDivider) ...[
                            const UnreadDivider(),
                            const SizedBox(height: 8),
                          ],
                          messageWidget,
                        ],
                      );
                    },
                  ),
          ),
          if (_isOtherUserTyping &&
              !_isForwardSelectionMode &&
              !_isDeleteSelectionMode)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.isGroup && _typingUserName != null
                        ? '$_typingUserName đang soạn tin...'
                        : 'Đang soạn tin...',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),
          if (_isForwardSelectionMode)
            ForwardSelectionBar(
              selectedCount: _forwardSelectedMessageIds.length,
              onForward: _onPressForwardSelected,
            )
          else if (_isDeleteSelectionMode)
            DeleteSelectionBar(
              selectedCount: _deleteSelectedMessageIds.length,
              onDelete: _onPressDeleteSelected,
            )
          else
            ChatInput(
              onSend: _handleSend,
              onSendImages: _handleSendImages,
              onSendVoice: _handleSendVoice,
              onTyping: _handleTyping,
              members: _groupMemberProfiles,
              isGroup: widget.isGroup,
              replyToMessage: _replyToMessage,
              onCancelReply: () {
                setState(() {
                  _replyToMessage = null;
                });
              },
            ),
        ],
      ),
    );
  }

  void _enterForwardSelectionMode(dynamic message) {
    final messageId = _messageIdOf(message);
    if (messageId.isEmpty || _messageType(message) == 3) return;
    if (_isMessageDeletedForEveryone(message)) return;
    if (_messageDisplayContent(message).trim().isEmpty) return;

    setState(() {
      _isForwardSelectionMode = true;
      _isDeleteSelectionMode = false;
      _replyToMessage = null;
      _deleteSelectedMessageIds.clear();
      _forwardSelectedMessageIds
        ..clear()
        ..add(messageId);
    });
  }

  void _toggleForwardMessageSelection(dynamic message) {
    final messageId = _messageIdOf(message);
    if (messageId.isEmpty) return;
    if (_isMessageDeletedForEveryone(message)) return;

    setState(() {
      if (_forwardSelectedMessageIds.contains(messageId)) {
        _forwardSelectedMessageIds.remove(messageId);
      } else {
        _forwardSelectedMessageIds.add(messageId);
      }

      if (_forwardSelectedMessageIds.isEmpty) {
        _isForwardSelectionMode = false;
      }
    });
  }

  void _cancelForwardSelectionMode() {
    setState(() {
      _isForwardSelectionMode = false;
      _forwardSelectedMessageIds.clear();
    });
  }

  Future<void> _onPressForwardSelected() async {
    if (_forwardSelectedMessageIds.isEmpty) return;
    final messagesToForward = _selectedForwardContents();
    if (messagesToForward.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có tin nhắn hợp lệ để chuyển tiếp'),
        ),
      );
      return;
    }

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ForwardRecipientsScreen(messagesToForward: messagesToForward),
      ),
    );

    final sent =
        (result is bool && result) || (result is Map && result['sent'] == true);

    if (sent && mounted) {
      _cancelForwardSelectionMode();
      await _refreshMessages();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã chuyển tiếp tin nhắn')));
    }
  }

  void _enterDeleteSelectionMode(dynamic message) {
    final messageId = _messageIdOf(message);
    if (messageId.isEmpty || _messageType(message) == 3) return;
    if (_isMessageDeletedForEveryone(message)) return;

    setState(() {
      _isDeleteSelectionMode = true;
      _isForwardSelectionMode = false;
      _replyToMessage = null;
      _forwardSelectedMessageIds.clear();
      _deleteSelectedMessageIds
        ..clear()
        ..add(messageId);
    });
  }

  void _toggleDeleteMessageSelection(dynamic message) {
    final messageId = _messageIdOf(message);
    if (messageId.isEmpty) return;
    if (_isMessageDeletedForEveryone(message)) return;

    setState(() {
      if (_deleteSelectedMessageIds.contains(messageId)) {
        _deleteSelectedMessageIds.remove(messageId);
      } else {
        _deleteSelectedMessageIds.add(messageId);
      }

      if (_deleteSelectedMessageIds.isEmpty) {
        _isDeleteSelectionMode = false;
      }
    });
  }

  void _cancelDeleteSelectionMode() {
    setState(() {
      _isDeleteSelectionMode = false;
      _deleteSelectedMessageIds.clear();
    });
  }

  void _cancelSelectionMode() {
    if (_isForwardSelectionMode) {
      _cancelForwardSelectionMode();
      return;
    }
    if (_isDeleteSelectionMode) {
      _cancelDeleteSelectionMode();
    }
  }

  Future<void> _onPressDeleteSelected() async {
    if (_deleteSelectedMessageIds.isEmpty) return;

    final selectedMessages = _messages.where((message) {
      final id = _messageIdOf(message);
      return _deleteSelectedMessageIds.contains(id);
    }).toList();

    if (selectedMessages.isEmpty) {
      _cancelDeleteSelectionMode();
      return;
    }

    await _showDeleteOptions(selectedMessages);
  }

  bool _isCurrentUserSender(dynamic message) {
    final senderId = _messageSenderId(message).toLowerCase();
    final currentId = (_currentUserId ?? '').toLowerCase();
    return senderId.isNotEmpty && senderId == currentId;
  }

  Future<void> _showDeleteOptions(List<dynamic> messages) async {
    if (messages.isEmpty) return;
    final allMyMessages = messages.every(_isCurrentUserSender);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) {
        Widget deleteAction({
          required String text,
          required bool forEveryone,
          bool isRed = false,
        }) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                Navigator.of(context).pop();
                await _deleteMessages(messages, forEveryone: forEveryone);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: isRed ? const Color(0xFFE53935) : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.only(top: 14, bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 36),
                      Text(
                        messages.length > 1
                            ? 'Xóa ${messages.length} tin nhắn?'
                            : 'Xóa tin nhắn?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      if (allMyMessages) ...[
                        deleteAction(
                          text: 'Xóa đối với mọi người',
                          forEveryone: true,
                          isRed: true,
                        ),
                        const Divider(height: 1),
                      ],
                      deleteAction(
                        text: 'Xóa cho tôi',
                        forEveryone: false,
                        isRed: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteMessages(
    List<dynamic> messages, {
    required bool forEveryone,
  }) async {
    if (_conversationId == null || messages.isEmpty) return;
    final messageIds = messages
        .map(_messageIdOf)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (messageIds.isEmpty) return;

    if (forEveryone) {
      for (final messageId in messageIds) {
        _markMessageDeletedForEveryoneLocally(
          messageId,
          deletedByUserId: _currentUserId,
        );
      }
    } else {
      _removeMessagesLocally(messageIds);
    }

    if (mounted) {
      setState(() {
        _isDeleteSelectionMode = false;
        _deleteSelectedMessageIds.clear();
      });
    }

    try {
      for (final message in messages) {
        final messageId = _messageIdOf(message);
        if (messageId.isEmpty) continue;

        final allowDeleteForEveryone =
            forEveryone && _isCurrentUserSender(message);
        await _chatService.deleteMessage(
          _conversationId!,
          messageId,
          forEveryone: allowDeleteForEveryone,
        );
      }
      _scheduleIncomingSync();
    } catch (e) {
      await _refreshMessages();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xóa tin nhắn thất bại: $e')));
    }
  }

  void _removeMessageLocally(String messageId) {
    _removeMessagesLocally({messageId});
  }

  void _removeMessagesLocally(Set<String> messageIds) {
    if (!mounted || messageIds.isEmpty) return;
    setState(() {
      _messages.removeWhere((m) => messageIds.contains(_messageIdOf(m)));
      _forwardSelectedMessageIds.removeAll(messageIds);
      _deleteSelectedMessageIds.removeAll(messageIds);
      if (_isForwardSelectionMode && _forwardSelectedMessageIds.isEmpty) {
        _isForwardSelectionMode = false;
      }
      if (_isDeleteSelectionMode && _deleteSelectedMessageIds.isEmpty) {
        _isDeleteSelectionMode = false;
      }
      _syncUnreadDividerWithCurrentMessages();
    });
  }

  void _markMessageDeletedForEveryoneLocally(
    String messageId, {
    String? deletedByUserId,
  }) {
    if (!mounted) return;

    setState(() {
      final index = _messages.indexWhere((m) => _messageIdOf(m) == messageId);
      if (index == -1) return;

      final original = _messages[index];
      final updated = Map<String, dynamic>.from(
        original is Map ? original : <String, dynamic>{},
      );

      updated['isDeletedForEveryone'] = true;
      updated['IsDeletedForEveryone'] = true;
      if (deletedByUserId != null && deletedByUserId.isNotEmpty) {
        updated['deletedForEveryoneByUserId'] = deletedByUserId;
        updated['DeletedForEveryoneByUserId'] = deletedByUserId;
      }

      updated['content'] = '';
      updated['Content'] = '';
      updated['replyToId'] = null;
      updated['ReplyToId'] = null;
      updated['replyToContent'] = null;
      updated['ReplyToContent'] = null;
      updated['replyToSenderName'] = null;
      updated['ReplyToSenderName'] = null;
      updated['reactions'] = <dynamic>[];
      updated['Reactions'] = <dynamic>[];

      _messages[index] = updated;
      _forwardSelectedMessageIds.remove(messageId);
      _deleteSelectedMessageIds.remove(messageId);
      if (_isForwardSelectionMode && _forwardSelectedMessageIds.isEmpty) {
        _isForwardSelectionMode = false;
      }
      if (_isDeleteSelectionMode && _deleteSelectedMessageIds.isEmpty) {
        _isDeleteSelectionMode = false;
      }
      _syncUnreadDividerWithCurrentMessages();
    });
  }

  // Selection bars moved to chat_selection_bars.dart

  String _formatTime(DateTime date) => helpers.formatTime(date);

  DateTime _parseMessageDate(dynamic message) =>
      helpers.parseMessageDate(message);

  String _messageIdOf(dynamic message) => helpers.messageIdOf(message);

  String _messageSenderId(dynamic message) => helpers.messageSenderId(message);

  int _messageType(dynamic message) => helpers.messageType(message);

  bool _isMessageDeletedForEveryone(dynamic message) =>
      helpers.isMessageDeletedForEveryone(message);

  bool _isForwardedMessage(dynamic message) =>
      helpers.isForwardedMessage(message);

  String _messageDisplayContent(dynamic message) =>
      helpers.messageDisplayContent(message, _currentUserId);

  String? _messageReplyDisplayContent(dynamic message) =>
      helpers.messageReplyDisplayContent(message);

  List<String> _selectedForwardContents() {
    final selected =
        _messages.where((message) {
          final messageId = _messageIdOf(message);
          return _forwardSelectedMessageIds.contains(messageId);
        }).toList()..sort(
          (a, b) => _parseMessageDate(a).compareTo(_parseMessageDate(b)),
        );

    return selected
        .where(
          (message) =>
              helpers.messageType(message) != 3 &&
              !helpers.isMessageDeletedForEveryone(message),
        )
        .map(
          (message) =>
              helpers.messageDisplayContent(message, _currentUserId).trim(),
        )
        .where((content) => content.isNotEmpty)
        .toList();
  }

  List<dynamic> _messageReadBy(dynamic message) =>
      helpers.messageReadBy(message);

  bool _isUnreadIncomingMessage(dynamic message) =>
      helpers.isUnreadIncomingMessage(message, _currentUserId);

  bool _shouldShowUnreadDivider(dynamic message) {
    if (!_showUnreadDivider || _unreadDividerMessageId == null) return false;
    return _messageIdOf(message) == _unreadDividerMessageId;
  }

  bool _shouldShowDateDivider(int index, DateTime date) =>
      helpers.shouldShowDateDivider(index, date, _messages);

  String _formatDayLabel(DateTime date) => helpers.formatDayLabel(date);

  String _timeAgo(DateTime d) => helpers.timeAgo(d);

  String _resolveReplyToLabel(dynamic message) {
    final replyToId =
        (message['replyToId'] ?? message['ReplyToId'])?.toString() ?? '';
    if (replyToId.isEmpty) return 'Đang trả lời';

    dynamic repliedMessage;
    for (final m in _messages) {
      final id = (m['id'] ?? m['Id'])?.toString() ?? '';
      if (id == replyToId) {
        repliedMessage = m;
        break;
      }
    }

    if (repliedMessage != null) {
      final repliedSenderId =
          (repliedMessage['senderId'] ?? repliedMessage['SenderId'])
              ?.toString();
      return _resolveDisplayNameForUserId(repliedSenderId);
    }

    final senderName =
        (message['replyToSenderName'] ?? message['ReplyToSenderName'])
            ?.toString()
            .trim();
    if (senderName != null && senderName.isNotEmpty) {
      return senderName;
    }

    return 'Đang trả lời';
  }

  String _resolveDisplayNameForUserId(String? userId) {
    return helpers.resolveDisplayNameForUserId(
      userId,
      currentUserId: _currentUserId,
      isGroup: widget.isGroup,
      otherUserName: widget.otherUserName,
      groupMemberProfiles: _groupMemberProfiles,
    );
  }

  String? _resolveGroupAvatarUrl(String? userId) =>
      helpers.resolveGroupAvatarUrl(userId, _groupMemberProfiles);

  Widget _buildEncryptionNotice() => const EncryptionNotice();

  bool get _isAdmin {
    if (!widget.isGroup || _creatorId == null || _currentUserId == null) {
      return false;
    }
    return _creatorId == _currentUserId;
  }

  Widget _buildStartOfChat() {
    return Column(
      children: [
        if (_isAdmin)
          GroupAdminDashboard(
            groupName: _groupName,
            groupAvatar: widget.otherUserAvatar,
            participantCount: _currentParticipantIds.length,
            onAddMember: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewGroupSelectMembersScreen(
                    isAddingToExistingGroup: true,
                    existingParticipantIds: _currentParticipantIds,
                    onParticipantsSelected: (selectedItems) async {
                      if (selectedItems.isEmpty) return;
                      try {
                        final ids = selectedItems.map((e) => e['id']!).toList();
                        final names = selectedItems
                            .map((e) => e['name']!)
                            .toList();

                        await _chatService.addParticipants(
                          _conversationId!,
                          ids,
                          names,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã thêm thành viên')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                        }
                      }
                    },
                  ),
                ),
              );
            },
            onManageMembers: _openGroupMembers,
            onInviteLink: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupInviteScreen(
                    groupName: _groupName,
                    inviteToken: _inviteToken,
                  ),
                ),
              );
            },
            onEditDescription: _showEditGroupDialog,
            onDisbandGroup: _disbandGroup,
          ),
        _buildEncryptionNotice(),
        const SizedBox(height: 16),
      ],
    );
  }
}
