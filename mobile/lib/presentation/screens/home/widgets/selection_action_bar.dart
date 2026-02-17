import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class SelectionActionBar extends StatelessWidget {
  final VoidCallback onArchive;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  const SelectionActionBar({
    super.key,
    required this.onArchive,
    required this.onMarkRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionButton(
              icon: Icons.archive_outlined,
              label: 'Lưu trữ',
              onTap: onArchive,
            ),
            _buildActionButton(
              icon: Icons.done_all,
              label: 'Đã đọc',
              onTap: onMarkRead,
            ),
            _buildActionButton(
              icon: Icons.delete_outline,
              label: 'Xóa',
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 24),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.navButton.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
