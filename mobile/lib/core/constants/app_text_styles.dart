import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  // Large Title (Chat)
  static const TextStyle largeTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  // Navigation Title
  static const TextStyle navTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Navigation Button
  static const TextStyle navButton = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.primary,
  );

  // Chat Name
  static const TextStyle chatName = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // Chat Message
  static const TextStyle chatMessage = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Chat Time
  static const TextStyle chatTime = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Tab Label
  static const TextStyle tabLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // Badge
  static const TextStyle badge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Search Placeholder
  static const TextStyle searchPlaceholder = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textPlaceholder,
  );

  // Filter Pill
  static const TextStyle filterPill = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}
