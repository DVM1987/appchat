import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GroupInviteScreen extends StatelessWidget {
  final String groupName;
  final String? inviteToken;

  const GroupInviteScreen({
    super.key,
    required this.groupName,
    this.inviteToken,
  });

  String get _inviteLink => 'appchat://join?token=$inviteToken';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mời vào nhóm'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Group Icon placeholder or real one
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue.withValues(alpha: 0.1),
              child: const Icon(Icons.group, size: 40, color: Colors.blue),
            ),
            const SizedBox(height: 16),
            Text(
              groupName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bất kỳ ai có liên kết này đều có thể tham gia nhóm.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // QR Code Section
            if (inviteToken != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _inviteLink,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
            ],
            
            // Invite Link Box
            _buildActionBox(
              context: context,
              title: 'Liên kết mời',
              content: _inviteLink,
              onCopy: () => _copyToClipboard(context, _inviteLink, 'Đã sao chép liên kết'),
            ),
            
            const SizedBox(height: 16),
            
            // Token Box
            _buildActionBox(
              context: context,
              title: 'Mã mời',
              subtitle: 'Dùng mã này để tham gia thủ công',
              content: inviteToken ?? '---',
              isToken: true,
              onCopy: () => _copyToClipboard(context, inviteToken ?? '', 'Đã sao chép mã mời'),
            ),
            
            const SizedBox(height: 40),
            
            // Note
            const Text(
              'Lưu ý: Bạn có thể thu hồi liên kết này bất cứ lúc nào trong phần cài đặt nhóm.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBox({
    required BuildContext context,
    required String title,
    String? subtitle,
    required String content,
    bool isToken = false,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: isToken ? 18 : 15,
                    fontWeight: isToken ? FontWeight.bold : FontWeight.w500,
                    color: isToken ? Colors.black87 : Colors.blue,
                    letterSpacing: isToken ? 2 : 0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                onPressed: onCopy,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
