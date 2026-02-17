import 'package:flutter/material.dart';

/// Dropdown list of mention suggestions shown above the chat input.
class MentionsList extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final String mentionQuery;
  final ValueChanged<Map<String, dynamic>> onMentionSelected;

  const MentionsList({
    super.key,
    required this.members,
    required this.mentionQuery,
    required this.onMentionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filteredMembers = members.where((m) {
      final name = (m['fullName'] ?? '').toString().toLowerCase();
      return name.contains(mentionQuery);
    }).toList();

    if (filteredMembers.isEmpty) {
      return const SizedBox.shrink();
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        constraints: const BoxConstraints(maxHeight: 240),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'GỢI Ý NHẮC TÊN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                    letterSpacing: 1,
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: filteredMembers.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, indent: 64, color: Colors.grey[100]),
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    final name = member['fullName'] ?? 'Unknown';
                    final avatarUrl =
                        member['avatarUrl'] ?? member['AvatarUrl'];

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue[50],
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        member['email'] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      onTap: () => onMentionSelected(member),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
