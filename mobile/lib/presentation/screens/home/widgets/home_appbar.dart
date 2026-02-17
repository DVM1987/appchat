import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import 'new_chat_bottom_sheet.dart';

class HomeTopBar extends StatelessWidget {
  final bool isSelectionMode;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback? onReadAll;

  const HomeTopBar({
    super.key,
    this.isSelectionMode = false,
    required this.onToggleSelectionMode,
    this.onReadAll,
  });

  Future<void> _onCameraPressed() async {
    final ImagePicker picker = ImagePicker();

    try {
      // Open camera to take a photo
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        // TODO: Handle the captured photo
        // For now, just print the path
        debugPrint('Photo captured: ${photo.path}');
        // You can navigate to a screen to send the photo or save it
      }
    } catch (e) {
      debugPrint('Error opening camera: $e');
      // TODO: Show error message to user
    }
  }

  void _onAddPressed(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NewChatBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isSelectionMode) {
      return _buildSelectionModeBar();
    }
    return _buildNormalBar(context);
  }

  Widget _buildSelectionModeBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Xong button
          TextButton(
            onPressed: onToggleSelectionMode,
            child: Text(
              'Xong',
              style: AppTextStyles.navButton.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
          // Empty space to balance layout
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildNormalBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 3-dot menu with popup
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_horiz,
              color: AppColors.iconPrimary,
              size: 24,
            ),
            color: AppColors.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            offset: const Offset(0, 50),
            onSelected: (value) {
              // Handle menu selection
              switch (value) {
                case 'select':
                  onToggleSelectionMode();
                  break;
                case 'read_all':
                  if (onReadAll != null) onReadAll!();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'select',
                child: Text(
                  'Chọn đoạn chat',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'read_all',
                child: Text(
                  'Đọc tất cả',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),

          Row(
            children: [
              // Camera icon
              IconButton(
                icon: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.iconPrimary,
                  size: 24,
                ),
                onPressed: _onCameraPressed,
              ),

              // Add button (green circle)
              GestureDetector(
                onTap: () => _onAddPressed(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: AppColors.background,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
