import 'package:flutter/material.dart';

/// Encryption notice banner shown at the top/bottom of the chat.
class EncryptionNotice extends StatelessWidget {
  const EncryptionNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5C4),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '🔒 Tin nhắn và cuộc gọi được mã hóa đầu cuối. Chỉ những người tham gia đoạn chat này mới có thể đọc, nghe hoặc chia sẻ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'Tìm hiểu thêm',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Date divider pill shown between messages on different dates.
class DateDivider extends StatelessWidget {
  final String date;

  const DateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          date,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ),
    );
  }
}

/// Unread messages divider pill.
class UnreadDivider extends StatelessWidget {
  const UnreadDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE8E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD0D0)),
        ),
        child: const Text(
          'Unread messages',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFFD32F2F),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
