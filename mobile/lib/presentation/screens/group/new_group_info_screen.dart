import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/chat_service.dart';
import '../../widgets/common/custom_avatar.dart';
import '../chat/chat_screen.dart';

class NewGroupInfoScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedMembers;

  const NewGroupInfoScreen({super.key, required this.selectedMembers});

  @override
  State<NewGroupInfoScreen> createState() => _NewGroupInfoScreenState();
}

class _NewGroupInfoScreenState extends State<NewGroupInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên nhóm')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentId = await AuthService.getUserId();
      final participantIds = widget.selectedMembers
          .map((m) => m['identityId'] ?? m['id'])
          .cast<String>()
          .toList();

      final conversationId = await _chatService.createGroupConversation(
        name,
        participantIds,
      );

      if (!mounted) return;

      // Add self to participant list for local display
      if (currentId != null) {
        participantIds.add(currentId);
      }

      // Navigate to Chat Screen AND remove new group screens from stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: conversationId, // For group, chatId IS conversationId
            otherUserName: name,
            isGroup: true, // Mark as group chat
            creatorId: currentId,
            participantIds: participantIds,
          ),
        ),
        (route) => route.isFirst, // Go back to Home
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo nhóm: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nhóm mới',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Tạo',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Name Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Tên nhóm (bắt buộc)',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Settings
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Tin nhắn tự hủy'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Tắt', style: TextStyle(color: Colors.grey)),
                        Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Quyền đối với nhóm'),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Members Count
            Text(
              'THÀNH VIÊN: ${widget.selectedMembers.length}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Members Grid/List
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ...widget.selectedMembers.map((member) {
                  return Column(
                    children: [
                      Stack(
                        children: [
                          CustomAvatar(
                            imageUrl: member['avatarUrl'],
                            name: member['fullName'] ?? 'U',
                            size: 50,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (member['fullName'] ?? 'User').split(' ')[0],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
