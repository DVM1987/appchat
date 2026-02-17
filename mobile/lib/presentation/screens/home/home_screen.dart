import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/chat_service.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../profile/profile_screen.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/chat_tab.dart';
import 'widgets/friends_tab.dart';
import 'widgets/placeholder_tab.dart';
import 'widgets/selection_action_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isSelectionMode = false;
  final Set<String> _selectedChatIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadData();
      ChatService().initSignalR();
      // Load hidden chats cache so filtering works immediately
      context.read<ChatProvider>().ensureHiddenChatsLoaded();
    });
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
        return const PlaceholderTab(tabName: 'Cập nhật');
      case 2:
        return const FriendsTab();
      case 3:
        return const PlaceholderTab(tabName: 'Cuộc gọi');
      case 4:
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
