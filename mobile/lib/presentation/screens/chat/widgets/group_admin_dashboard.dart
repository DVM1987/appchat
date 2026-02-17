import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../widgets/common/custom_avatar.dart';

class GroupAdminDashboard extends StatelessWidget {
  final String groupName;
  final String? groupAvatar;
  final int participantCount;
  final VoidCallback onAddMember;
  final VoidCallback onManageMembers;
  final VoidCallback onInviteLink;
  final VoidCallback onEditDescription;
  final VoidCallback? onDisbandGroup;

  const GroupAdminDashboard({
    super.key,
    required this.groupName,
    this.groupAvatar,
    required this.participantCount,
    required this.onAddMember,
    required this.onManageMembers,
    required this.onInviteLink,
    required this.onEditDescription,
    this.onDisbandGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          CustomAvatar(
            imageUrl: groupAvatar,
            name: groupName,
            size: 64,
            showOnlineIndicator: false,
          ),
          const SizedBox(height: 12),

          // Title
          const Text(
            'Bạn đã tạo nhóm này',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),

          // Subtitle
          Text(
            'Nhóm · $participantCount thành viên',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 12),

          // Edit Description
          GestureDetector(
            onTap: onEditDescription,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Thêm mô tả',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Helper for buttons
          _buildActionButton(
            label: 'Thêm thành viên',
            icon: Icons.add,
            onTap: onAddMember,
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'Xóa thành viên',
            icon: Icons.person_remove_outlined,
            onTap: onManageMembers,
          ),
          const SizedBox(height: 12),
          if (onDisbandGroup != null) ...[
            _buildActionButton(
              label: 'Giải tán nhóm',
              icon: Icons.delete_forever_outlined,
              onTap: onDisbandGroup!,
              color: Colors.red[50],
              textColor: Colors.red,
            ),
            const SizedBox(height: 12),
          ],
          _buildActionButton(
            label: 'Mời qua liên kết',
            icon: Icons.link,
            onTap: onInviteLink,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    Color? textColor,
  }) {
    return Material(
      color: color ?? const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: textColor ?? Colors.black87),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
