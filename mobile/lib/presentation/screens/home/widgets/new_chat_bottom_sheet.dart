import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/custom_avatar.dart';
import '../../chat/chat_screen.dart';
import '../../group/new_group_select_members_screen.dart';
import '../add_contact_screen.dart';

class NewChatBottomSheet extends StatefulWidget {
  const NewChatBottomSheet({super.key});

  @override
  State<NewChatBottomSheet> createState() => _NewChatBottomSheetState();
}

class _NewChatBottomSheetState extends State<NewChatBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleFriendTap(Map<String, dynamic> friend) {
    // Navigate immediately to ChatScreen
    // ChatScreen handles creating/fetching the conversation
    final friendId = friend['identityId'] ?? friend['id'];
    final friendName = friend['fullName'] ?? 'Unknown';
    final friendAvatar = friend['avatarUrl'];

    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: friendId,
          otherUserName: friendName,
          otherUserAvatar: friendAvatar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final friends = userProvider.friends;
        final filteredFriends = friends.where((friend) {
          final name = (friend['fullName'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery);
        }).toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Search bar
              _buildSearchBar(),

              // Content List
              Expanded(
                child: ListView(
                  children: [
                    // Menu options (Only show if not searching or match logic)
                    if (_searchQuery.isEmpty) ...[
                      _buildMenuItem(
                        icon: Icons.group_outlined,
                        iconColor: AppColors.primary,
                        title: 'Nhóm mới',
                        onTap: () {
                          Navigator.pop(context); // Close bottom sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NewGroupSelectMembersScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.person_add_outlined,
                        iconColor: AppColors.primary,
                        title: 'Người liên hệ mới',
                        onTap: () {
                          Navigator.pop(context); // Close bottom sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddContactScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.people_outline,
                        iconColor: AppColors.primary,
                        title: 'Cộng đồng mới',
                        subtitle:
                            'Tập trung các nhóm chung chủ đề vào cùng một nơi',
                        onTap: () {
                          // TODO: Navigate to create community
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.campaign_outlined,
                        iconColor: AppColors.primary,
                        title: 'Danh sách nhận tin mới',
                        onTap: () {
                          // TODO: Navigate to create broadcast
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Danh bạ trên WhatsApp',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],

                    // Contacts List
                    if (filteredFriends.isEmpty && _searchQuery.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'Không tìm thấy kết quả',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ...filteredFriends.map((friend) {
                        return _buildContactItem(friend);
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Đoạn chat mới',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.iconPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.iconSecondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: AppTextStyles.chatMessage.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm tên hoặc số',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(bottom: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.chatName),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.chatMessage.copyWith(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(Map<String, dynamic> friend) {
    final name = friend['fullName'] ?? 'Unknown';
    final avatarUrl = friend['avatarUrl'];
    final status = friend['status'] ?? 'Offline';
    final isOnline = status == 'Online' || status == 1;

    // Use 'email' or 'identityId' as a subtitle/phone number placeholder
    // In real app, you might have a 'phoneNumber' field
    final subtitle = friend['email'] ?? 'Đang sử dụng WhatsApp';

    return InkWell(
      onTap: () => _handleFriendTap(friend),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CustomAvatar(
              imageUrl: avatarUrl,
              name: name,
              size: 45,
              showOnlineIndicator: isOnline,
              isOnline: isOnline,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.chatName),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.chatMessage.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
