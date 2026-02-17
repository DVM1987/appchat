import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/services/auth_service.dart';
import '../../../providers/chat_provider.dart';
import 'chat_item.dart';

class ChatList extends StatefulWidget {
  final bool isSelectionMode;
  final Set<String> selectedChatIds;
  final Function(String) onChatSelected;

  const ChatList({
    super.key,
    this.isSelectionMode = false,
    this.selectedChatIds = const {},
    required this.onChatSelected,
  });

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Load conversations once when widget is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatProvider>();
      if (!provider.hasConversations && !provider.isLoading) {
        provider.loadConversations();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when user scrolls near bottom (200px before end)
      final provider = context.read<ChatProvider>();
      if (!provider.isLoadingMore && provider.hasMoreData) {
        provider.loadMoreConversations();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${provider.error}',
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadConversations(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!provider.hasConversations) {
          return RefreshIndicator(
            onRefresh: () => provider.refreshConversations(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 200),
                Center(
                  child: Text(
                    'No conversations yet',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.refreshConversations(),
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount:
                provider.conversations.length +
                (provider.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Show loading indicator at bottom
              if (index == provider.conversations.length) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final conversation = provider.conversations[index];
              return ChatItem(
                conversation: conversation,
                isSelectionMode: widget.isSelectionMode,
                isSelected: widget.selectedChatIds.contains(conversation.id),
                onTap: () async {
                  if (widget.isSelectionMode) {
                    widget.onChatSelected(conversation.id);
                  } else {
                    if (conversation.isGroup) {
                      Navigator.pushNamed(
                        context,
                        '/chat',
                        arguments: {
                          'chatId': conversation.id,
                          'otherUserName': conversation.name,
                          'otherUserAvatar': conversation.avatarUrl,
                          'isGroup': true,
                          'creatorId': conversation.creatorId,
                          'participantIds': conversation.participantIds,
                        },
                      );
                    } else {
                      // Resolve partner info for 1-1 chats
                      final currentUserId = await AuthService.getUserId();
                      if (currentUserId == null) return;
                      if (!context.mounted) return;

                      final partnerId = conversation.participantIds.firstWhere(
                        (id) => id != currentUserId,
                        orElse: () => '',
                      );

                      // Navigate to chat detail
                      Navigator.pushNamed(
                        context,
                        '/chat',
                        arguments: {
                          'chatId': partnerId,
                          'otherUserName': conversation.name,
                          'otherUserAvatar': conversation.avatarUrl,
                        },
                      );
                    }
                  }
                },
                onArchive: () {
                  provider.archiveConversation(conversation.id);
                },
              );
            },
          ),
        );
      },
    );
  }
}
