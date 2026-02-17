import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class PlaceholderTab extends StatelessWidget {
  final String tabName;

  const PlaceholderTab({super.key, required this.tabName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(tabName, style: AppTextStyles.largeTitle),
          const SizedBox(height: 8),
          Text('Tính năng đang phát triển', style: AppTextStyles.chatMessage),
        ],
      ),
    );
  }
}
