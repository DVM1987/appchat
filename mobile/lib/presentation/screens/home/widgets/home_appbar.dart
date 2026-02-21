import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/services/chat_service.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/custom_avatar.dart';
import '../../chat/chat_screen.dart';
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

  Future<void> _onCameraPressed(BuildContext context) async {
    final ImagePicker picker = ImagePicker();

    try {
      // 1. Open camera
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo == null) return; // User cancelled
      if (!context.mounted) return;

      // 2. Show preview + pick recipient
      _showPhotoPreviewAndPicker(context, File(photo.path));
    } catch (e) {
      AppConfig.log('Error opening camera: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể mở camera: $e')));
      }
    }
  }

  void _showPhotoPreviewAndPicker(BuildContext context, File photoFile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PhotoPreviewRecipientPicker(photoFile: photoFile),
    );
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
          // 3-dot menu
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
                onPressed: () => _onCameraPressed(context),
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

// ─── Photo Preview + Recipient Picker ───────────────────────────────────────

class _PhotoPreviewRecipientPicker extends StatefulWidget {
  final File photoFile;

  const _PhotoPreviewRecipientPicker({required this.photoFile});

  @override
  State<_PhotoPreviewRecipientPicker> createState() =>
      _PhotoPreviewRecipientPickerState();
}

class _PhotoPreviewRecipientPickerState
    extends State<_PhotoPreviewRecipientPicker> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSending = false;
  String? _sendingToName;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendToFriend(Map<String, dynamic> friend) async {
    final friendId = friend['identityId'] ?? friend['id'];
    final friendName = friend['fullName'] ?? 'Unknown';
    final friendAvatar = friend['avatarUrl'];

    setState(() {
      _isSending = true;
      _sendingToName = friendName;
    });

    try {
      final chatService = ChatService();

      // 1. Get or create conversation with this friend
      final conversationId = await chatService.createConversation(friendId);

      // 2. Upload and send image
      await chatService.sendImageMessages(conversationId, [widget.photoFile]);

      if (!mounted) return;

      // 3. Close bottom sheet
      Navigator.pop(context);

      // 4. Navigate to chat screen
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã gửi ảnh cho $friendName')));
    } catch (e) {
      AppConfig.log('Error sending photo: $e');
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi gửi ảnh: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Photo preview
          _buildPhotoPreview(),

          // Divider
          const Divider(color: AppColors.divider, height: 1),

          // Sending indicator
          if (_isSending) _buildSendingIndicator(),

          // Search bar
          _buildSearchBar(),

          // Label
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Gửi cho',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          // Friends list
          Expanded(child: _buildFriendsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Gửi ảnh cho...',
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

  Widget _buildPhotoPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(widget.photoFile, fit: BoxFit.cover),
            // Gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Chọn người nhận bên dưới',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Đang gửi ảnh cho $_sendingToName...',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
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
                decoration: const InputDecoration(
                  hintText: 'Tìm bạn bè...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(bottom: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final friends = userProvider.friends;
        final filteredFriends = friends.where((friend) {
          final name = (friend['fullName'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery);
        }).toList();

        if (filteredFriends.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Không tìm thấy bạn bè'
                      : 'Chưa có bạn bè nào',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredFriends.length,
          itemBuilder: (context, index) {
            final friend = filteredFriends[index];
            return _buildFriendItem(friend);
          },
        );
      },
    );
  }

  Widget _buildFriendItem(Map<String, dynamic> friend) {
    final name = friend['fullName'] ?? 'Unknown';
    final avatarUrl = friend['avatarUrl'];

    return InkWell(
      onTap: _isSending ? null : () => _sendToFriend(friend),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CustomAvatar(imageUrl: avatarUrl, name: name, size: 45),
            const SizedBox(width: 14),
            Expanded(child: Text(name, style: AppTextStyles.chatName)),
            // Send icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
