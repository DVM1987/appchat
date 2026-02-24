import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/date_formatter.dart';

void main() {
  group('DateFormatter', () {
    group('formatChatTimestamp', () {
      test('shows time (HH:mm) for today', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 14, 30);
        // Only test if it's still "today" at runtime
        if (now.day == today.day) {
          final result = DateFormatter.formatChatTimestamp(today);
          expect(result, '14:30');
        }
      });

      test('shows day name for this week (1-6 days ago)', () {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final result = DateFormatter.formatChatTimestamp(yesterday);
        // Should be a day name (e.g. "Monday", "Tuesday")
        expect(
          result,
          anyOf([
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
            // Vietnamese locale possible
            contains('Th'),
          ]),
        );
      });

      test('shows date (M/d/yy) for older than a week', () {
        final oldDate = DateTime(2025, 11, 19, 10, 0);
        final result = DateFormatter.formatChatTimestamp(oldDate);
        expect(result, '11/19/25');
      });

      test('handles midnight correctly', () {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day, 0, 0);
        if (now.day == midnight.day) {
          final result = DateFormatter.formatChatTimestamp(midnight);
          expect(result, '00:00');
        }
      });

      test('handles end of day correctly', () {
        final now = DateTime.now();
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59);
        if (now.day == endOfDay.day) {
          final result = DateFormatter.formatChatTimestamp(endOfDay);
          expect(result, '23:59');
        }
      });
    });

    group('formatDuration', () {
      test('formats zero seconds', () {
        expect(DateFormatter.formatDuration(Duration.zero), '0:00');
      });

      test('formats seconds only', () {
        expect(
          DateFormatter.formatDuration(const Duration(seconds: 14)),
          '0:14',
        );
      });

      test('formats single digit seconds with padding', () {
        expect(
          DateFormatter.formatDuration(const Duration(seconds: 5)),
          '0:05',
        );
      });

      test('formats minutes and seconds', () {
        expect(
          DateFormatter.formatDuration(const Duration(minutes: 3, seconds: 42)),
          '3:42',
        );
      });

      test('formats over an hour', () {
        expect(
          DateFormatter.formatDuration(
            const Duration(hours: 1, minutes: 5, seconds: 30),
          ),
          '65:30',
        );
      });

      test('formats exactly one minute', () {
        expect(
          DateFormatter.formatDuration(const Duration(minutes: 1)),
          '1:00',
        );
      });

      test('formats 59 seconds', () {
        expect(
          DateFormatter.formatDuration(const Duration(seconds: 59)),
          '0:59',
        );
      });
    });
  });
}
