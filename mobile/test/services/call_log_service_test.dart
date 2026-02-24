import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/models/call_log_model.dart';
import 'package:mobile/data/services/call_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CallLogService', () {
    late CallLogService service;

    setUp(() {
      // Initialize SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      service = CallLogService();
    });

    CallLog createLog({
      String id = 'log-1',
      CallStatus status = CallStatus.completed,
      int durationSeconds = 60,
    }) {
      return CallLog(
        id: id,
        otherUserId: 'user-1',
        otherUserName: 'Test User',
        callType: CallType.audio,
        direction: CallDirection.outgoing,
        status: status,
        startedAt: DateTime(2026, 2, 24, 10, 0),
        durationSeconds: durationSeconds,
      );
    }

    test('getLogs returns empty list initially', () async {
      final logs = await service.getLogs();
      expect(logs, isEmpty);
    });

    test('addLog adds a log and retrieves it', () async {
      await service.addLog(createLog());
      final logs = await service.getLogs();
      expect(logs.length, 1);
      expect(logs.first.id, 'log-1');
      expect(logs.first.otherUserName, 'Test User');
    });

    test('addLog inserts newest first', () async {
      await service.addLog(createLog(id: 'old'));
      await service.addLog(createLog(id: 'new'));
      final logs = await service.getLogs();
      expect(logs.length, 2);
      expect(logs.first.id, 'new');
      expect(logs.last.id, 'old');
    });

    test('addLog caps at 100 entries', () async {
      // Add 105 logs
      for (int i = 0; i < 105; i++) {
        await service.addLog(createLog(id: 'log-$i'));
      }
      final logs = await service.getLogs();
      expect(logs.length, 100);
      // Most recent should be first
      expect(logs.first.id, 'log-104');
    });

    test('updateLog updates status', () async {
      await service.addLog(createLog(status: CallStatus.missed));
      await service.updateLog('log-1', status: CallStatus.completed);

      final logs = await service.getLogs();
      expect(logs.first.status, CallStatus.completed);
    });

    test('updateLog updates duration', () async {
      await service.addLog(createLog(durationSeconds: 0));
      await service.updateLog('log-1', durationSeconds: 300);

      final logs = await service.getLogs();
      expect(logs.first.durationSeconds, 300);
    });

    test('updateLog does nothing for non-existent id', () async {
      await service.addLog(createLog());
      await service.updateLog('non-existent', status: CallStatus.rejected);

      final logs = await service.getLogs();
      expect(logs.length, 1);
      expect(logs.first.status, CallStatus.completed); // unchanged
    });

    test('clearLogs removes all logs', () async {
      await service.addLog(createLog(id: 'a'));
      await service.addLog(createLog(id: 'b'));
      expect((await service.getLogs()).length, 2);

      await service.clearLogs();
      final logs = await service.getLogs();
      expect(logs, isEmpty);
    });

    test('generateId returns unique UUIDs', () {
      final id1 = CallLogService.generateId();
      final id2 = CallLogService.generateId();
      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);
      expect(id1, isNot(equals(id2)));
    });
  });
}
