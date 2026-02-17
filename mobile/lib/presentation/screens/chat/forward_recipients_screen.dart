import 'package:flutter/material.dart';

import '../../../data/services/chat_service.dart';
import '../../../data/services/user_service.dart';
import '../../widgets/common/custom_avatar.dart';
import 'forward_message_codec.dart';

class ForwardRecipientsScreen extends StatefulWidget {
  final List<String> messagesToForward;

  const ForwardRecipientsScreen({super.key, required this.messagesToForward});

  @override
  State<ForwardRecipientsScreen> createState() =>
      _ForwardRecipientsScreenState();
}

class _ForwardRecipientsScreenState extends State<ForwardRecipientsScreen> {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _friends = [];
  final Set<String> _selectedFriendIds = <String>{};
  bool _isLoading = true;
  bool _isSending = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final raw = await _userService.getFriends();
    if (!mounted) return;

    setState(() {
      _friends
        ..clear()
        ..addAll(
          raw.whereType<Map>().map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      _isLoading = false;
    });
  }

  String _friendId(Map<String, dynamic> friend) {
    return (friend['identityId'] ?? friend['id'] ?? '').toString();
  }

  List<String> _friendSendCandidateIds(Map<String, dynamic> friend) {
    final identityId = (friend['identityId'] ?? friend['IdentityId'] ?? '')
        .toString()
        .trim();
    final profileId = (friend['id'] ?? friend['Id'] ?? '').toString().trim();
    final candidates = <String>[];
    if (identityId.isNotEmpty) {
      candidates.add(identityId);
    }
    if (profileId.isNotEmpty && profileId != identityId) {
      candidates.add(profileId);
    }
    return candidates;
  }

  String _friendName(Map<String, dynamic> friend) {
    return (friend['fullName'] ?? friend['name'] ?? 'Người dùng').toString();
  }

  String _friendSubtitle(Map<String, dynamic> friend) {
    return (friend['email'] ?? friend['phoneNumber'] ?? '').toString();
  }

  List<Map<String, dynamic>> get _filteredFriends {
    if (_searchQuery.isEmpty) return _friends;
    return _friends.where((friend) {
      final name = _friendName(friend).toLowerCase();
      final subtitle = _friendSubtitle(friend).toLowerCase();
      return name.contains(_searchQuery) || subtitle.contains(_searchQuery);
    }).toList();
  }

  void _toggleRecipient(Map<String, dynamic> friend) {
    final id = _friendId(friend);
    if (id.isEmpty) return;
    setState(() {
      if (_selectedFriendIds.contains(id)) {
        _selectedFriendIds.remove(id);
      } else {
        _selectedFriendIds.add(id);
      }
    });
  }

  Future<void> _sendForwardedMessages() async {
    if (_selectedFriendIds.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final messages = widget.messagesToForward
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList();
      if (messages.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có nội dung để chuyển tiếp')),
        );
        setState(() {
          _isSending = false;
        });
        return;
      }

      for (final selectedId in _selectedFriendIds) {
        final friend = _friends.firstWhere(
          (f) => _friendId(f) == selectedId,
          orElse: () => <String, dynamic>{},
        );
        if (friend.isEmpty) continue;

        final candidateIds = _friendSendCandidateIds(friend);
        if (candidateIds.isEmpty) {
          throw Exception(
            'Không tìm thấy ID hợp lệ để gửi tới ${_friendName(friend)}',
          );
        }

        Exception? lastError;
        bool sent = false;
        for (final candidateId in candidateIds) {
          try {
            final conversationId = await _chatService.createConversation(
              candidateId,
            );
            for (final message in messages) {
              await _chatService.sendMessage(
                conversationId,
                ForwardMessageCodec.encode(message),
              );
            }
            sent = true;
            break;
          } catch (e) {
            lastError = Exception(e.toString());
          }
        }

        if (!sent) {
          throw Exception(
            'Gửi tới ${_friendName(friend)} thất bại: ${lastError?.toString() ?? "unknown"}',
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context, {
        'sent': true,
        'recipientIds': _selectedFriendIds.toList(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chuyển tiếp thất bại: $e')));
      setState(() {
        _isSending = false;
      });
    }
  }

  void _onPressRightAction() {
    if (_isSending) return;
    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tính năng tạo nhóm mới sẽ cập nhật sau')),
      );
      return;
    }
    _sendForwardedMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredFriends.isEmpty
                  ? const Center(
                      child: Text(
                        'Không có bạn bè để chuyển tiếp',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 8, 4, 10),
                          child: Text(
                            'Danh bạ',
                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ..._filteredFriends.map(_buildFriendItem),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Row(
        children: [
          TextButton(
            onPressed: _isSending ? null : () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Gửi đến',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          TextButton(
            onPressed: _onPressRightAction,
            child: Text(
              _isSending
                  ? 'Đang gửi...'
                  : (_selectedFriendIds.isEmpty ? 'Nhóm mới' : 'Gửi'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _selectedFriendIds.isEmpty
                    ? Colors.black
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.black45),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(Map<String, dynamic> friend) {
    final id = _friendId(friend);
    final isSelected = _selectedFriendIds.contains(id);
    final name = _friendName(friend);
    final subtitle = _friendSubtitle(friend);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: _isSending ? null : () => _toggleRecipient(friend),
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            CustomAvatar(
              imageUrl: friend['avatarUrl']?.toString(),
              name: name,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFF25D366) : Colors.black38,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}
