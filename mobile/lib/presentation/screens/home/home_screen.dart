// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/call_log_model.dart';
import '../../../data/services/call_log_service.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/deep_link_service.dart';
import '../../../data/services/push_notification_service.dart';
import '../../providers/call_log_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/update_dialog.dart';
import '../call/call_screen.dart' as cs;
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/calls_tab.dart';
import 'widgets/chat_tab.dart';
import 'widgets/friends_tab.dart';
import 'widgets/selection_action_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isSelectionMode = false;
  final Set<String> _selectedChatIds = {};
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Clear app icon badge when app opens
    PushNotificationService.clearBadge();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeInit();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Clear badge when app comes to foreground
      PushNotificationService.clearBadge();
    }
  }

  /// Safely initialize all services — each wrapped individually
  /// so a failure in one doesn't crash the entire app.
  Future<void> _safeInit() async {
    // 1. Load user data
    try {
      context.read<UserProvider>().loadData();
    } catch (e) {
      debugPrint('[HomeScreen] UserProvider.loadData error: $e');
    }

    // 2. Initialize SignalR (with timeout to prevent hanging)
    try {
      await ChatService().initSignalR().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[HomeScreen] SignalR init timed out after 10s');
        },
      );
    } catch (e) {
      debugPrint('[HomeScreen] SignalR init error: $e');
    }

    // 3. Load hidden chats cache
    try {
      context.read<ChatProvider>().ensureHiddenChatsLoaded();
    } catch (e) {
      debugPrint('[HomeScreen] ensureHiddenChatsLoaded error: $e');
    }

    // 4. Listen for incoming calls
    try {
      _setupIncomingCallListener();
    } catch (e) {
      debugPrint('[HomeScreen] setupIncomingCallListener error: $e');
    }

    // 5. Listen for deep links
    try {
      _setupDeepLinkListener();
    } catch (e) {
      debugPrint('[HomeScreen] setupDeepLinkListener error: $e');
    }

    // 6. Setup push notification handlers
    try {
      _setupPushNotifications();
    } catch (e) {
      debugPrint('[HomeScreen] setupPushNotifications error: $e');
    }

    // 7. Check for app updates (soft/force)
    try {
      UpdateDialog.checkAndShow(context);
    } catch (e) {
      debugPrint('[HomeScreen] UpdateDialog.checkAndShow error: $e');
    }
  }

  void _setupPushNotifications() {
    final pushService = PushNotificationService();

    // Re-register FCM token after login
    pushService.reRegisterToken();

    // Show in-app banner for foreground notifications
    pushService.onForegroundNotification = (notification) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(notification.body),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    };

    // Navigate to conversation when notification tapped
    pushService.onNavigateToConversation =
        (
          conversationId, {
          String? senderName,
          bool isGroup = false,
          String? conversationName,
        }) {
          if (!mounted) return;
          AppConfig.log(
            '[Push] Navigate to conversation: $conversationId, sender: $senderName, isGroup: $isGroup',
          );
          // For group: show group name; for 1-1: show sender name
          final displayName = isGroup
              ? (conversationName ?? senderName ?? 'Nhóm chat')
              : (senderName ?? 'Chat');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: conversationId,
                otherUserName: displayName,
                isGroup: isGroup,
              ),
            ),
          );
        };

    // Navigate to friends tab when friend request notification tapped
    pushService.onNavigateToFriends = () {
      if (mounted) {
        setState(() => _currentIndex = 1); // Friends tab (new index)
      }
    };
  }

  void _setupDeepLinkListener() {
    final deepLinkService = DeepLinkService();

    // Handle initial link (app opened via deep link)
    final initial = deepLinkService.initialLink;
    if (initial != null) {
      DeepLinkService.handleDeepLink(context, initial);
    }

    // Listen for subsequent links
    _deepLinkSub = deepLinkService.deepLinkStream.listen((uri) {
      if (mounted) {
        DeepLinkService.handleDeepLink(context, uri);
      }
    });
  }

  void _setupIncomingCallListener() {
    ChatService().onIncomingCall = (callData) {
      if (!mounted) return;
      final callerId = callData['callerId'] ?? callData['CallerId'] ?? '';
      final callerName =
          callData['callerName'] ??
          callData['CallerName'] ??
          'Ng\u01b0\u1eddi d\u00f9ng';
      final callerAvatar = callData['callerAvatar'] ?? callData['CallerAvatar'];
      final callTypeStr =
          callData['callType'] ?? callData['CallType'] ?? 'audio';
      final callType = callTypeStr == 'video'
          ? cs.CallType.video
          : cs.CallType.audio;

      // Record incoming call log (initially as missed, updated if accepted)
      final callLogId = CallLogService.generateId();
      final callLog = CallLog(
        id: callLogId,
        otherUserId: callerId,
        otherUserName: callerName,
        otherUserAvatar: callerAvatar is String && callerAvatar.isNotEmpty
            ? callerAvatar
            : null,
        callType: callTypeStr == 'video' ? CallType.video : CallType.audio,
        direction: CallDirection.incoming,
        status: CallStatus.missed, // Default to missed, updated if connected
        startedAt: DateTime.now(),
      );
      context.read<CallLogProvider>().addLog(callLog);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => cs.CallScreen(
            calleeName: callerName,
            calleeAvatar: callerAvatar is String && callerAvatar.isNotEmpty
                ? callerAvatar
                : null,
            callType: callType,
            callRole: cs.CallRole.callee,
            otherUserId: callerId,
            callLogId: callLogId,
          ),
        ),
      );
    };
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      _isSelectionMode = false;
      _selectedChatIds.clear();
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedChatIds.clear();
      }
    });
  }

  void _toggleChatSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  void _selectAllChats() {
    final provider = context.read<ChatProvider>();
    setState(() {
      _selectedChatIds.addAll(provider.allVisibleConversationIds);
    });
  }

  void _deselectAllChats() {
    setState(() {
      _selectedChatIds.clear();
    });
  }

  void _onReadAll() {
    context.read<ChatProvider>().markAllConversationsAsRead();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã đọc tất cả tin nhắn')));
  }

  void _onDeleteSelected() {
    if (_selectedChatIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa đoạn chat',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Bạn có chắc muốn xoá ${_selectedChatIds.length} đoạn chat?\n\nCác đoạn chat sẽ bị ẩn khỏi danh sách và không hiện lại nữa.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performDelete();
            },
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete() async {
    final provider = context.read<ChatProvider>();
    await provider.hideConversations(Set.from(_selectedChatIds));
    if (mounted) {
      setState(() {
        _selectedChatIds.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xoá đoạn chat')));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allIds = context.watch<ChatProvider>().allVisibleConversationIds;
    final allSelected =
        allIds.isNotEmpty &&
        allIds.every((id) => _selectedChatIds.contains(id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _buildTabContent(allSelected)),
      bottomNavigationBar: _isSelectionMode
          ? SelectionActionBar(
              onArchive: () {
                // TODO: Archive selected chats
              },
              onMarkRead: () {
                // TODO: Mark as read
              },
              onDelete: _onDeleteSelected,
            )
          : BottomNavBar(currentIndex: _currentIndex, onTap: _onTabTapped),
    );
  }

  Widget _buildTabContent(bool allSelected) {
    switch (_currentIndex) {
      case 0:
        return ChatTab(
          isSelectionMode: _isSelectionMode,
          selectedChatIds: _selectedChatIds,
          onToggleSelectionMode: _toggleSelectionMode,
          onChatSelected: _toggleChatSelection,
          onSelectAll: allSelected ? _deselectAllChats : _selectAllChats,
          onReadAll: _onReadAll,
          allSelected: allSelected,
        );
      case 1:
        return const FriendsTab();
      case 2:
        return const CallsTab();
      case 3:
        return const ProfileScreen();
      default:
        return ChatTab(
          isSelectionMode: _isSelectionMode,
          selectedChatIds: _selectedChatIds,
          onToggleSelectionMode: _toggleSelectionMode,
          onChatSelected: _toggleChatSelection,
          onSelectAll: allSelected ? _deselectAllChats : _selectAllChats,
          onReadAll: _onReadAll,
          allSelected: allSelected,
        );
    }
  }
}
