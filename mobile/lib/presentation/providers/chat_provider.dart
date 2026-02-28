import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../data/models/conversation_model.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/hidden_chats_service.dart';
import '../../data/services/push_notification_service.dart';
import '../../data/services/user_service.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository = ChatRepositoryImpl();
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final HiddenChatsService _hiddenChatsService = HiddenChatsService();
  final List<StreamSubscription> _subscriptions = [];
  Timer? _presenceRefreshTimer;
  final Map<String, Timer> _pendingOfflineTimers = {};

  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String _searchQuery = '';

  // Pagination (for future API integration)
  // ignore: unused_field
  int _currentPage = 1; // Will be used when calling API with page parameter
  // ignore: unused_field
  static const int _pageSize = 10; // Will be used for pagination limit
  bool _hasMoreData = true;

  // Getters
  List<Conversation> get conversations => _filteredConversations;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasConversations => _conversations.isNotEmpty;
  bool get hasMoreData => _hasMoreData;
  int get totalUnreadCount =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  /// All visible conversation IDs (for "Select All" feature).
  List<String> get allVisibleConversationIds =>
      _filteredConversations.map((c) => c.id).toList();

  void clear() {
    _conversations = [];
    _filteredConversations = [];
    _processedMessageIds.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  ChatProvider() {
    _initPresenceListeners();
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    _presenceRefreshTimer?.cancel();
    // Every 60 seconds, do a full presence sync just in case we missed SignalR events
    _presenceRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_conversations.isNotEmpty && !_isLoading) {
        _fetchPresenceForConversations();
      }
    });
  }

  void _initPresenceListeners() {
    _subscriptions.add(_chatService.userOnlineStream.listen(_onUserOnline));
    _subscriptions.add(_chatService.userOfflineStream.listen(_onUserOffline));
    _subscriptions.add(_chatService.messageStream.listen(_onMessageReceived));
    _subscriptions.add(_chatService.messageReadStream.listen(_onMessageRead));
    _subscriptions.add(
      _chatService.conversationCreatedStream.listen(_onConversationCreated),
    );
    _subscriptions.add(
      _chatService.conversationUpdatedStream.listen(_onConversationUpdated),
    );
    _subscriptions.add(
      _chatService.conversationDeletedStream.listen(_onConversationDeleted),
    );
  }

  void _onConversationDeleted(String conversationId) {
    _conversations.removeWhere((c) => c.id == conversationId);
    _applyFilter();
    notifyListeners();
  }

  void _onConversationCreated(dynamic data) {
    _handleConversationUpdate(data, isNew: true);
  }

  void _onConversationUpdated(dynamic data) {
    _handleConversationUpdate(data, isNew: false);
  }

  void _handleConversationUpdate(dynamic data, {required bool isNew}) async {
    try {
      if (data is Map<String, dynamic>) {
        final newConversation = ConversationModel.fromJson(data);
        final currentUserId = await AuthService.getUserId();

        // If I'm no longer in the group, remove it from list
        if (currentUserId != null &&
            !newConversation.participantIds.contains(currentUserId)) {
          _conversations.removeWhere((c) => c.id == newConversation.id);
          _applyFilter();
          notifyListeners();
          return;
        }

        final index = _conversations.indexWhere(
          (c) => c.id == newConversation.id,
        );

        if (index != -1) {
          // Update existing: Keep current unreadCount if it's an update notice
          // ALSO keep current isOnline status!
          final updatedConv = newConversation.copyWith(
            unreadCount: isNew
                ? newConversation.unreadCount
                : _conversations[index].unreadCount,
            isOnline: _conversations[index].isOnline,
          );
          _conversations[index] = updatedConv;
        } else {
          // Add new
          _conversations.insert(0, newConversation);
        }

        if (!newConversation.isGroup) {
          _resolveUserNames();
        }

        _applyFilter();
        notifyListeners();
      }
    } catch (e) {
      AppConfig.log('Error parsing conversation update: $e');
    }
  }

  void _onUserOnline(String userId) {
    // If there's a pending offline timer for this user, cancel it
    // This handles the "Flicker" where user goes offline then immediately online
    if (_pendingOfflineTimers.containsKey(userId)) {
      _pendingOfflineTimers[userId]?.cancel();
      _pendingOfflineTimers.remove(userId);
      AppConfig.log(
        'ChatProvider: Cancelled pending offline update for $userId',
      );
    }
    _updatePresence(userId, true);
  }

  void _onUserOffline(String userId) {
    // Debounce offline updates by 3 seconds
    // If the user reconnects within 5 seconds, we ignore the offline event
    if (_pendingOfflineTimers.containsKey(userId)) {
      _pendingOfflineTimers[userId]?.cancel();
    }

    AppConfig.log('ChatProvider: Scheduling offline update for $userId in 5s');
    _pendingOfflineTimers[userId] = Timer(const Duration(seconds: 5), () {
      AppConfig.log('ChatProvider: Executing offline update for $userId');
      _updatePresence(userId, false);
      _pendingOfflineTimers.remove(userId);
    });
  }

  final Set<String> _processedMessageIds = {};

  void _onMessageReceived(dynamic message) {
    final messageId = message['id'] ?? message['Id'];
    if (messageId != null) {
      if (_processedMessageIds.contains(messageId)) {
        AppConfig.log('ChatProvider: Ignored duplicate message $messageId');
        return;
      }
      _processedMessageIds.add(messageId);
    }

    final convId = message['conversationId'] ?? message['ConversationId'];
    final content = message['content'] ?? message['Content'];
    final senderId = message['senderId'] ?? message['SenderId'];

    AuthService.getUserId().then((currentUserId) {
      if (currentUserId == null) return;

      final index = _conversations.indexWhere((c) => c.id == convId);
      if (index != -1) {
        var conv = _conversations[index];
        int newUnread = conv.unreadCount;

        // If message is from others, increment unread
        if (senderId != currentUserId) {
          newUnread++;
        }

        final updatedConv = conv.copyWith(
          lastMessage: content,
          lastMessageTime: DateTime.now(),
          unreadCount: newUnread,
        );

        _conversations.removeAt(index);
        _conversations.insert(0, updatedConv);
        _applyFilter();
        notifyListeners();
      } else {
        // New conversation, reload list
        loadConversations(refresh: true);
      }
    });
  }

  void _onMessageRead(Map<String, String> data) {
    final convId = data['conversationId'];
    final userId = data['userId']; // Who read it

    AuthService.getUserId().then((currentUserId) {
      if (currentUserId == null || convId == null) return;

      // If I read the conversation (on another device), reset unread count
      if (userId == currentUserId) {
        final index = _conversations.indexWhere((c) => c.id == convId);
        if (index != -1) {
          final updatedConv = _conversations[index].copyWith(unreadCount: 0);
          _conversations[index] = updatedConv;
          _applyFilter();
          notifyListeners();
        }
      }
    });
  }

  void _updatePresence(String userId, bool isOnline) {
    bool changed = false;
    final normalizedUserId = userId.toLowerCase();

    final updatedConversations = _conversations.map((conversation) {
      // Check if this conversation involves the user (Case-Insensitive)
      final hasUser = conversation.participantIds.any(
        (id) => id.toLowerCase() == normalizedUserId,
      );

      if (hasUser && !conversation.isGroup) {
        if (conversation.isOnline != isOnline) {
          changed = true;
          return conversation.copyWith(isOnline: isOnline);
        }
      }
      return conversation;
    }).toList();

    if (changed) {
      _conversations = updatedConversations;
      _applyFilter();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _presenceRefreshTimer?.cancel();
    for (var timer in _pendingOfflineTimers.values) {
      timer.cancel();
    }
    _pendingOfflineTimers.clear();
    super.dispose();
  }

  /// Load conversations from repository (Pull-to-refresh)
  Future<void> loadConversations({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreData = true;
      _conversations.clear();
      _filteredConversations.clear();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Ensure hidden chats list is loaded for filtering
      await _hiddenChatsService.getHiddenChatIds();

      // In real scenario, pass page and pageSize to API
      final newConversations = await _repository.getConversations();

      // Ensure SignalR is connected if we have data
      if (newConversations.isNotEmpty) {
        // Initializing SignalR here ensures we are connected when viewing lists
        // Ideally this is called at app start, but here is safe too.
        await _chatService.initSignalR();
      }

      // Merge isOnline status from old list to new list to prevent flickering
      if (_conversations.isNotEmpty) {
        final onlineStatusMap = {
          for (var c in _conversations) c.id: c.isOnline,
        };

        for (var i = 0; i < newConversations.length; i++) {
          if (onlineStatusMap.containsKey(newConversations[i].id)) {
            newConversations[i] = newConversations[i].copyWith(
              isOnline: onlineStatusMap[newConversations[i].id],
            );
          }
        }
      }

      if (refresh) {
        _conversations = newConversations;
      } else {
        _conversations.addAll(newConversations);
      }

      // Fetch initial presence
      if (_conversations.isNotEmpty) {
        await _fetchPresenceForConversations();
        _resolveUserNames(); // Fire and forget or await? Await to show correct names fast.
      }

      _applyFilter();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _conversations = [];
      _filteredConversations = [];
    } finally {
      _isLoading = false;
      notifyListeners();
      // Sync app icon badge with total unread count
      PushNotificationService.updateBadge(totalUnreadCount);
    }
  }

  Future<void> _fetchPresenceForConversations() async {
    try {
      final currentUserId = await AuthService.getUserId();
      if (currentUserId == null) return;

      final userIds = _conversations
          .expand((c) => c.participantIds)
          .where((id) => id != currentUserId)
          .toSet()
          .toList();

      AppConfig.log(
        'ChatProvider: Fetching presence for ${userIds.length} users: $userIds',
      );

      final presences = await _chatService.getPresences(userIds);
      AppConfig.log('ChatProvider: Raw presence response: $presences');

      // CRITICAL: If we couldn't get any presence data (e.g. hub disconnected),
      // do NOT update the list to offline, as it might just be a connection flicker.
      if (presences.isEmpty) {
        AppConfig.log(
          'ChatProvider: getPresences returned empty. Skipping presence update to avoid flickering.',
        );
        return;
      }

      // Build a map for quick lookup
      final presenceMap = {
        for (var p in presences)
          (p['userId'] ?? p['UserId'] ?? p['userid']).toString(): p,
      };

      bool changed = false;
      final updatedConversations = _conversations.map((c) {
        // Find other user in this conversation
        final otherUserId = c.participantIds.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty && presenceMap.containsKey(otherUserId)) {
          final p = presenceMap[otherUserId]!;
          final status = p['status'] ?? p['Status'] ?? 'Offline';
          final isOnline = status == 'Online' || status == '1';

          // Log active users for debugging
          if (isOnline) {
            AppConfig.log('ChatProvider: Found Online User: $otherUserId');
          }

          if (c.isOnline != isOnline) {
            changed = true;
            return c.copyWith(isOnline: isOnline);
          }
        }
        // CRITICAL UPDATE: If otherUserId is NOT in presenceMap (missing from response),
        // do NOT update status. This assumes that if they were truly offline,
        // the server would have returned 'Offline' OR we would have received a UserOffline event.
        // This prevents wholesale clearing of online status if the presence check fails partially.

        return c;
      }).toList();

      if (changed) {
        _conversations = updatedConversations;
        _applyFilter(); // Ensure filtered list is also updated
        notifyListeners();
      }
    } catch (e) {
      AppConfig.log('Error fetching presence: $e');
    }
  }

  /// Load more conversations (Scroll to bottom)
  Future<void> loadMoreConversations() async {
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;

      // Simulate loading more data
      // In real scenario: await _repository.getConversations(page: _currentPage, pageSize: _pageSize)
      await Future.delayed(const Duration(seconds: 1));

      // For demo: just duplicate existing data with different IDs
      final moreConversations = await _repository.getConversations();

      // Check if we have more data (in real scenario, check response)
      if (moreConversations.isEmpty) {
        _hasMoreData = false;
      } else {
        _conversations.addAll(moreConversations);
        _applyFilter();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refresh conversations (Pull-to-refresh)
  Future<void> refreshConversations() async {
    await loadConversations(refresh: true);
  }

  /// Search conversations
  void searchConversations(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _applyFilter();
    notifyListeners();
  }

  /// Archive conversation
  Future<void> archiveConversation(String conversationId) async {
    try {
      await _repository.archiveConversation(conversationId);
      await loadConversations(refresh: true); // Refresh list
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _repository.deleteConversation(conversationId);
      await loadConversations(refresh: true); // Refresh list
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Mark all conversations as read — sets unreadCount to 0 for all.
  /// Updates UI immediately, then calls backend markAsRead in background.
  Future<void> markAllConversationsAsRead() async {
    bool changed = false;
    final updatedConversations = _conversations.map((c) {
      if (c.unreadCount > 0) {
        changed = true;
        return c.copyWith(unreadCount: 0);
      }
      return c;
    }).toList();

    if (changed) {
      _conversations = updatedConversations;
      _applyFilter();
      notifyListeners();

      // Fire-and-forget: call backend markAsRead for each unread conversation
      for (final c in updatedConversations) {
        try {
          await _chatService.markAsRead(c.id);
        } catch (e) {
          AppConfig.log('Error marking ${c.id} as read: $e');
        }
      }
    }
  }

  /// Apply filter based on search query and hidden chats.
  void _applyFilter() {
    // Start from all conversations
    var result = List<Conversation>.from(_conversations);

    // Filter out hidden chats
    final hiddenIds = _hiddenChatsService.cachedHiddenIds;
    if (hiddenIds.isNotEmpty) {
      result = result.where((c) => !hiddenIds.contains(c.id)).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      result = result
          .where(
            (conv) =>
                conv.name.toLowerCase().contains(_searchQuery) ||
                (conv.lastMessage?.toLowerCase().contains(_searchQuery) ??
                    false),
          )
          .toList();
    }

    _filteredConversations = result;
  }

  Future<void> _resolveUserNames() async {
    final currentUserId = await AuthService.getUserId();
    if (currentUserId == null) return;

    bool changed = false;
    final futures = _conversations.map((c) async {
      if (!c.isGroup && (c.name == 'Chat' || c.name == 'New Conversation')) {
        final otherUserId = c.participantIds.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty) {
          final profile = await _userService.getUserProfile(otherUserId);
          if (profile != null) {
            final name = profile['fullName'] ?? profile['email'] ?? 'User';
            String? avatar = profile['avatarUrl'] ?? c.avatarUrl;
            if (avatar != null && !avatar.startsWith('http')) {
              avatar = '${AuthService.baseUrl}$avatar';
            }
            if (c.name != name || c.avatarUrl != avatar) {
              changed = true;
              return c.copyWith(name: name, avatarUrl: avatar);
            }
          }
        }
      }
      return c;
    });

    final results = await Future.wait(futures);

    if (changed) {
      _conversations = results;
      _applyFilter();
      notifyListeners();
    }
  }

  /// Hide conversations locally (only on mobile, NOT deleted from DB).
  /// Once hidden, they won't appear on the home screen ever again
  /// unless explicitly un-hidden.
  Future<void> hideConversations(Set<String> conversationIds) async {
    await _hiddenChatsService.hideChats(conversationIds);
    _applyFilter();
    notifyListeners();
  }

  /// Ensure hidden chats cache is loaded before applying filters.
  Future<void> ensureHiddenChatsLoaded() async {
    await _hiddenChatsService.getHiddenChatIds();
  }
}
