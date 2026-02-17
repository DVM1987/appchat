import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class SearchBarWidget extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const SearchBarWidget({super.key, this.onChanged, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.searchBarBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        onChanged: onChanged,
        onTap: onTap,
        style: AppTextStyles.searchPlaceholder,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm',
          hintStyle: AppTextStyles.searchPlaceholder,
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.iconSecondary,
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
