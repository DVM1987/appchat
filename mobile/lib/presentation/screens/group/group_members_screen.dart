import 'package:flutter/material.dart';

import '../../../../data/services/auth_service.dart';
import '../../../../data/services/chat_service.dart';
import '../../widgets/common/custom_avatar.dart';
import 'new_group_select_members_screen.dart';

class GroupMembersScreen extends StatefulWidget {
  final String conversationId;
  final List<Map<String, dynamic>> members;
  final String? creatorId;
  final bool isAdmin;
  final Function(List<Map<String, dynamic>>) onMembersUpdated;

  const GroupMembersScreen({
    super.key,
    required this.conversationId,
    required this.members,
    this.creatorId,
    required this.isAdmin,
    required this.onMembersUpdated,
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final ChatService _chatService = ChatService();
  late List<Map<String, dynamic>> _members;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _members = List.from(widget.members);
    _init();
  }

  Future<void> _init() async {
    _currentUserId = await AuthService.getUserId();
    if (mounted) setState(() {});
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final memberId =
        member['identityId'] ??
        member['IdentityId'] ??
        member['id'] ??
        member['Id'];
    final name = member['fullName'] ?? member['FullName'] ?? 'Người dùng';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thành viên'),
        content: Text('Bạn có chắc chắn muốn xóa $name khỏi nhóm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _chatService.removeParticipant(
          widget.conversationId,
          memberId,
          name,
        );

        setState(() {
          _members.removeWhere((m) => (m['id'] ?? m['Id']) == memberId);
        });
        widget.onMembersUpdated(_members);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Đã xóa $name')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời nhóm'),
        content: const Text('Bạn có chắc chắn muốn rời khỏi nhóm này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rời nhóm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final myName = (await AuthService.getUserName()) ?? 'Thành viên';
        await _chatService.leaveConversation(widget.conversationId, myName);
        if (mounted) {
          Navigator.pop(context, true); // Return true indicating we left
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thành viên nhóm'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewGroupSelectMembersScreen(
                      isAddingToExistingGroup: true,
                      existingParticipantIds: _members
                          .map((e) => (e['id'] ?? e['Id']).toString())
                          .toList(),
                      onParticipantsSelected: (selectedItems) async {
                        if (selectedItems.isEmpty) return;
                        try {
                          final ids = selectedItems
                              .map((e) => e['id']!)
                              .toList();
                          final names = selectedItems
                              .map((e) => e['name']!)
                              .toList();

                          await _chatService.addParticipants(
                            widget.conversationId,
                            ids,
                            names,
                          );

                          // We don't update local state here because ChatScreen will get
                          // the SignalR event and we'll probably go back anyway.
                          // But for better UX, we could refresh.

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã thêm thành viên'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: _members.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = _members[index];
                final id =
                    member['identityId'] ??
                    member['IdentityId'] ??
                    member['id'] ??
                    member['Id'];
                final name =
                    member['fullName'] ?? member['FullName'] ?? 'Unknown';
                final isCreator = id == widget.creatorId;
                final isMe = id == _currentUserId;

                return ListTile(
                  leading: CustomAvatar(
                    imageUrl: member['avatarUrl'] ?? member['AvatarUrl'],
                    name: name,
                    size: 40,
                  ),
                  title: Text(
                    name + (isMe ? ' (Bạn)' : ''),
                    style: TextStyle(
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: isCreator
                      ? const Text(
                          'Trưởng nhóm',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        )
                      : null,
                  trailing: widget.isAdmin && !isCreator && !isMe
                      ? IconButton(
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeMember(member),
                        )
                      : null,
                );
              },
            ),
          ),
          if (!widget.isAdmin)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _leaveGroup,
                  icon: const Icon(Icons.logout),
                  label: const Text('Rời khỏi nhóm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red[100]!),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
