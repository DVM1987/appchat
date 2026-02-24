import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/services/auth_service.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/custom_avatar.dart';
import '../../chat/chat_screen.dart';
import '../../group/qr_scanner_screen.dart';
import '../../profile/my_qr_code_screen.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, UserProvider>(
      builder: (context, chatProvider, userProvider, child) {
        if (userProvider.isLoading && userProvider.friends.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: userProvider.loadData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // QR Code Actions
              Row(
                children: [
                  Expanded(
                    child: _buildQrButton(
                      icon: Icons.qr_code,
                      label: 'QR của tôi',
                      color: AppColors.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyQrCodeScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQrButton(
                      icon: Icons.qr_code_scanner,
                      label: 'Quét mã QR',
                      color: Colors.green,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QrScannerScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Pending Requests Section
              if (userProvider.pendingRequests.isNotEmpty) ...[
                const Text(
                  'Lời mời kết bạn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...userProvider.pendingRequests.map(
                  (req) => _buildRequestItem(req, userProvider),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
              ],

              // 3. Friends List Section
              const Text(
                'Danh sách bạn bè',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (userProvider.friends.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'Chưa có bạn bè nào.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...userProvider.friends.map((friend) {
                  final friendIdentityId = friend['identityId'];
                  int unreadCount = 0;
                  bool isOnline = false;
                  try {
                    final conversation = chatProvider.conversations.firstWhere(
                      (c) =>
                          !c.isGroup &&
                          c.participantIds.contains(friendIdentityId),
                    );
                    unreadCount = conversation.unreadCount;
                    isOnline = conversation.isOnline;
                  } catch (_) {}
                  return _buildFriendItem(friend, unreadCount, isOnline);
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestItem(dynamic request, UserProvider provider) {
    final requester = request['requester'] ?? {};
    final name = requester['fullName'] ?? 'Người dùng';
    final avatarUrl = requester['avatarUrl'];
    final requesterId = requester['id'];

    String? fullAvatarUrl = avatarUrl;
    if (fullAvatarUrl != null && !fullAvatarUrl.startsWith('http')) {
      fullAvatarUrl = '${AuthService.baseUrl}$fullAvatarUrl';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CustomAvatar(imageUrl: fullAvatarUrl, name: name, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Đã gửi lời mời kết bạn',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => provider.acceptRequest(requesterId),
                  tooltip: 'Chấp nhận',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => provider.declineRequest(requesterId),
                  tooltip: 'Từ chối',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(dynamic friend, int unreadCount, bool isOnline) {
    final name = friend['fullName'] ?? 'Bạn bè';
    final avatarUrl = friend['avatarUrl'];

    String? fullAvatarUrl = avatarUrl;
    if (fullAvatarUrl != null && !fullAvatarUrl.startsWith('http')) {
      fullAvatarUrl = '${AuthService.baseUrl}$fullAvatarUrl';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.background,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        leading: CustomAvatar(
          imageUrl: fullAvatarUrl,
          name: name,
          size: 50,
          showOnlineIndicator: true,
          isOnline: isOnline,
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              color: AppColors.primary,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatId: friend['identityId'],
                      otherUserName: name,
                      otherUserAvatar: fullAvatarUrl,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.blue,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
