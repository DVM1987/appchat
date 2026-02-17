import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/user_provider.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Consumer2<ChatProvider, UserProvider>(
        builder: (context, chatProvider, userProvider, child) {
          final totalUnread = chatProvider.totalUnreadCount;
          final pendingFriends = userProvider.pendingCount;

          return BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTap,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.surface,
            selectedItemColor: AppColors.textPrimary,
            unselectedItemColor: AppColors.textSecondary,
            selectedLabelStyle: AppTextStyles.tabLabel.copyWith(
              color: AppColors.textPrimary,
            ),
            unselectedLabelStyle: AppTextStyles.tabLabel,
            items: [
              BottomNavigationBarItem(
                icon: totalUnread > 0
                    ? Badge(
                        label: Text('$totalUnread'),
                        child: const Icon(Icons.chat_bubble_outline),
                      )
                    : const Icon(Icons.chat_bubble_outline),
                activeIcon: totalUnread > 0
                    ? Badge(
                        label: Text('$totalUnread'),
                        child: const Icon(Icons.chat_bubble),
                      )
                    : const Icon(Icons.chat_bubble),
                label: 'Chat',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.update_outlined),
                activeIcon: Icon(Icons.update),
                label: 'Cập nhật',
              ),
              BottomNavigationBarItem(
                icon: pendingFriends > 0
                    ? Badge(
                        label: Text('$pendingFriends'),
                        child: const Icon(Icons.people_outline),
                      )
                    : const Icon(Icons.people_outline),
                activeIcon: pendingFriends > 0
                    ? Badge(
                        label: Text('$pendingFriends'),
                        child: const Icon(Icons.people),
                      )
                    : const Icon(Icons.people),
                label: 'Danh bạ',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.call_outlined),
                activeIcon: Icon(Icons.call),
                label: 'Cuộc gọi',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Bạn',
              ),
            ],
          );
        },
      ),
    );
  }
}
