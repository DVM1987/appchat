import 'package:flutter/material.dart';

import '../../../../core/constants/app_text_styles.dart';
import 'chat_list.dart';
import 'filter_pills.dart';
import 'home_appbar.dart';
import 'search_bar_widget.dart';

class ChatTab extends StatelessWidget {
  final bool isSelectionMode;
  final Set<String> selectedChatIds;
  final VoidCallback onToggleSelectionMode;
  final void Function(String) onChatSelected;
  final VoidCallback? onSelectAll;
  final VoidCallback? onReadAll;
  final bool allSelected;

  const ChatTab({
    super.key,
    required this.isSelectionMode,
    required this.selectedChatIds,
    required this.onToggleSelectionMode,
    required this.onChatSelected,
    this.onSelectAll,
    this.onReadAll,
    this.allSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top bar (3-dot, camera, add) OR Xong button
        HomeTopBar(
          isSelectionMode: isSelectionMode,
          onToggleSelectionMode: onToggleSelectionMode,
          onReadAll: onReadAll,
        ),

        // Large "Chat" title or "Đã chọn X"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            isSelectionMode
                ? (selectedChatIds.isNotEmpty
                      ? 'Đã chọn ${selectedChatIds.length}'
                      : 'Chọn đoạn chat')
                : 'Chat',
            style: AppTextStyles.largeTitle,
          ),
        ),

        // Search bar
        const SearchBarWidget(),

        // Filter pills — in selection mode, "Tất cả" pill selects all
        FilterPills(
          isSelectionMode: isSelectionMode,
          onSelectAll: onSelectAll,
          allSelected: allSelected,
        ),

        // Chat list with selection mode
        Expanded(
          child: ChatList(
            isSelectionMode: isSelectionMode,
            selectedChatIds: selectedChatIds,
            onChatSelected: onChatSelected,
          ),
        ),
      ],
    );
  }
}
