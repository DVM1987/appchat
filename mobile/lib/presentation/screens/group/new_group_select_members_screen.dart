import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/custom_avatar.dart';
import 'new_group_info_screen.dart';

class NewGroupSelectMembersScreen extends StatefulWidget {
  final bool isAddingToExistingGroup;
  final List<String> existingParticipantIds;
  final Function(List<Map<String, String>>)? onParticipantsSelected;

  const NewGroupSelectMembersScreen({
    super.key,
    this.isAddingToExistingGroup = false,
    this.existingParticipantIds = const [],
    this.onParticipantsSelected,
  });

  @override
  State<NewGroupSelectMembersScreen> createState() =>
      _NewGroupSelectMembersScreenState();
}

class _NewGroupSelectMembersScreenState
    extends State<NewGroupSelectMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedMemberIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    // Ensure data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    if (widget.isAddingToExistingGroup &&
        widget.existingParticipantIds.contains(id)) {
      return; // Can't deselect already present members in "Add Mode"
    }

    setState(() {
      if (_selectedMemberIds.contains(id)) {
        _selectedMemberIds.remove(id);
      } else {
        _selectedMemberIds.add(id);
      }
    });
  }

  void _onNextPressed() {
    if (widget.isAddingToExistingGroup) {
      if (widget.onParticipantsSelected != null) {
        final friends = context.read<UserProvider>().friends;
        final selected = friends
            .where((f) => _selectedMemberIds.contains(f['identityId'] ?? f['id']))
            .map((f) => {
              'id': (f['identityId'] ?? f['id']).toString(),
              'name': (f['fullName'] ?? 'User').toString(),
            })
            .toList();
        widget.onParticipantsSelected!(selected);
      }
      Navigator.pop(context);
      return;
    }

    final friends = context.read<UserProvider>().friends;
    final selectedFriends = friends
        .where((f) => _selectedMemberIds.contains(f['identityId'] ?? f['id']))
        .map((f) => Map<String, dynamic>.from(f))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NewGroupInfoScreen(selectedMembers: selectedFriends),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Hủy',
            style: TextStyle(color: AppColors.primary, fontSize: 16),
          ),
        ),
        leadingWidth: 70,
        title: Column(
          children: [
            Text(
              widget.isAddingToExistingGroup ? 'Thêm người' : 'Thêm thành viên',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Consumer<UserProvider>(
              builder: (context, provider, _) {
                return Text(
                  '${_selectedMemberIds.length}/${provider.friends.length}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _selectedMemberIds.isNotEmpty ? _onNextPressed : null,
            child: Text(
              widget.isAddingToExistingGroup ? 'Thêm' : 'Tiếp theo',
              style: TextStyle(
                color: _selectedMemberIds.isNotEmpty
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: AppColors.iconSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: AppTextStyles.chatMessage,
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm tên hoặc số',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(bottom: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Friend List with A-Z Index (Simplified)
          Expanded(
            child: Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                if (userProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final friends = userProvider.friends;
                final filteredFriends = friends.where((friend) {
                  final name = (friend['fullName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                // Group by first letter
                final grouped = <String, List<dynamic>>{};
                for (var f in filteredFriends) {
                  final name = f['fullName'] ?? '';
                  if (name.isNotEmpty) {
                    final initial = name[0].toUpperCase();
                    grouped.putIfAbsent(initial, () => []).add(f);
                  }
                }
                final sortedKeys = grouped.keys.toList()..sort();

                return Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: sortedKeys.length,
                        itemBuilder: (context, index) {
                          final key = sortedKeys[index];
                          final groupFriends = grouped[key]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Text(
                                  key,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...groupFriends.map((friend) {
                                final id =
                                    friend['identityId'] ??
                                    friend['id']; // Prefer IdentityId
                                final isAlreadyInGroup =
                                    widget.isAddingToExistingGroup &&
                                    widget.existingParticipantIds.contains(id);
                                final isSelected =
                                    isAlreadyInGroup ||
                                    _selectedMemberIds.contains(id);

                                return ListTile(
                                  onTap: () => _toggleSelection(id),
                                  enabled: !isAlreadyInGroup,
                                  leading: Opacity(
                                    opacity: isAlreadyInGroup ? 0.5 : 1.0,
                                    child: CustomAvatar(
                                      imageUrl: friend['avatarUrl'],
                                      name: friend['fullName'] ?? 'U',
                                      size: 40,
                                      showOnlineIndicator: false,
                                    ),
                                  ),
                                  title: Text(
                                    friend['fullName'] ?? 'Unknown',
                                    style: AppTextStyles.chatName.copyWith(
                                      color: isAlreadyInGroup
                                          ? Colors.grey
                                          : Colors.black,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isAlreadyInGroup
                                        ? 'Đã tham gia nhóm'
                                        : (friend['email'] ??
                                            friend['identityId'] ??
                                            'Đang sử dụng WhatsApp'),
                                    style: AppTextStyles.chatMessage.copyWith(
                                      fontSize: 13,
                                      color: isAlreadyInGroup
                                          ? Colors.grey
                                          : AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? (isAlreadyInGroup
                                                ? Colors.grey
                                                : AppColors.primary)
                                            : Colors.grey,
                                        width: 2,
                                      ),
                                      color: isSelected
                                          ? (isAlreadyInGroup
                                              ? Colors.grey[300]
                                              : AppColors.primary)
                                          : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
                    // Quick Index Bar
                    Container(
                      width: 20,
                      alignment: Alignment.center,
                      child: ListView.builder(
                        itemCount: sortedKeys.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              sortedKeys[index],
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
