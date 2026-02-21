import 'package:intl/intl.dart';

class DateFormatter {
  /// Format chat timestamp (e.g., "11/19/19")
  static String formatChatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today - show time
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays < 7) {
      // This week - show day name
      return DateFormat('EEEE').format(dateTime);
    } else {
      // Older - show date
      return DateFormat('M/d/yy').format(dateTime);
    }
  }

  /// Format voice note duration (e.g., "0:14")
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }
}
