import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/models/call_log_model.dart';

void main() {
  group('CallLog Model', () {
    final now = DateTime(2026, 2, 24, 10, 30, 0);

    CallLog createSampleLog({
      CallType callType = CallType.audio,
      CallDirection direction = CallDirection.outgoing,
      CallStatus status = CallStatus.completed,
      int durationSeconds = 120,
    }) {
      return CallLog(
        id: 'test-id-1',
        otherUserId: 'user-123',
        otherUserName: 'Văn Mười',
        otherUserAvatar: 'https://example.com/avatar.jpg',
        callType: callType,
        direction: direction,
        status: status,
        startedAt: now,
        durationSeconds: durationSeconds,
      );
    }

    group('Constructor', () {
      test('creates instance with all required fields', () {
        final log = createSampleLog();
        expect(log.id, 'test-id-1');
        expect(log.otherUserId, 'user-123');
        expect(log.otherUserName, 'Văn Mười');
        expect(log.otherUserAvatar, 'https://example.com/avatar.jpg');
        expect(log.callType, CallType.audio);
        expect(log.direction, CallDirection.outgoing);
        expect(log.status, CallStatus.completed);
        expect(log.startedAt, now);
        expect(log.durationSeconds, 120);
      });

      test('default durationSeconds is 0', () {
        final log = CallLog(
          id: 'id',
          otherUserId: 'uid',
          otherUserName: 'name',
          callType: CallType.audio,
          direction: CallDirection.incoming,
          status: CallStatus.missed,
          startedAt: now,
        );
        expect(log.durationSeconds, 0);
      });

      test('otherUserAvatar is optional (null)', () {
        final log = CallLog(
          id: 'id',
          otherUserId: 'uid',
          otherUserName: 'name',
          callType: CallType.video,
          direction: CallDirection.outgoing,
          status: CallStatus.rejected,
          startedAt: now,
        );
        expect(log.otherUserAvatar, isNull);
      });
    });

    group('copyWith', () {
      test('copies with new status', () {
        final original = createSampleLog(status: CallStatus.missed);
        final updated = original.copyWith(status: CallStatus.completed);
        expect(updated.status, CallStatus.completed);
        expect(updated.id, original.id);
        expect(updated.otherUserName, original.otherUserName);
        expect(updated.durationSeconds, original.durationSeconds);
      });

      test('copies with new durationSeconds', () {
        final original = createSampleLog(durationSeconds: 0);
        final updated = original.copyWith(durationSeconds: 300);
        expect(updated.durationSeconds, 300);
        expect(updated.status, original.status);
      });

      test('copies with both status and duration', () {
        final original = createSampleLog(
          status: CallStatus.missed,
          durationSeconds: 0,
        );
        final updated = original.copyWith(
          status: CallStatus.completed,
          durationSeconds: 45,
        );
        expect(updated.status, CallStatus.completed);
        expect(updated.durationSeconds, 45);
      });

      test('preserves all fields when no arguments provided', () {
        final original = createSampleLog();
        final copy = original.copyWith();
        expect(copy.id, original.id);
        expect(copy.otherUserId, original.otherUserId);
        expect(copy.otherUserName, original.otherUserName);
        expect(copy.otherUserAvatar, original.otherUserAvatar);
        expect(copy.callType, original.callType);
        expect(copy.direction, original.direction);
        expect(copy.status, original.status);
        expect(copy.startedAt, original.startedAt);
        expect(copy.durationSeconds, original.durationSeconds);
      });
    });

    group('Serialization (toJson / fromJson)', () {
      test('toJson produces correct map', () {
        final log = createSampleLog();
        final json = log.toJson();
        expect(json['id'], 'test-id-1');
        expect(json['otherUserId'], 'user-123');
        expect(json['otherUserName'], 'Văn Mười');
        expect(json['otherUserAvatar'], 'https://example.com/avatar.jpg');
        expect(json['callType'], 'audio');
        expect(json['direction'], 'outgoing');
        expect(json['status'], 'completed');
        expect(json['startedAt'], now.toIso8601String());
        expect(json['durationSeconds'], 120);
      });

      test('fromJson parses correctly', () {
        final json = {
          'id': 'test-id-2',
          'otherUserId': 'user-456',
          'otherUserName': 'Test User',
          'otherUserAvatar': null,
          'callType': 'video',
          'direction': 'incoming',
          'status': 'missed',
          'startedAt': '2026-02-24T15:00:00.000',
          'durationSeconds': 0,
        };
        final log = CallLog.fromJson(json);
        expect(log.id, 'test-id-2');
        expect(log.otherUserId, 'user-456');
        expect(log.otherUserName, 'Test User');
        expect(log.otherUserAvatar, isNull);
        expect(log.callType, CallType.video);
        expect(log.direction, CallDirection.incoming);
        expect(log.status, CallStatus.missed);
        expect(log.durationSeconds, 0);
      });

      test('roundtrip: toJson → fromJson preserves data', () {
        final original = createSampleLog();
        final jsonStr = jsonEncode(original.toJson());
        final restored = CallLog.fromJson(jsonDecode(jsonStr));
        expect(restored.id, original.id);
        expect(restored.otherUserId, original.otherUserId);
        expect(restored.otherUserName, original.otherUserName);
        expect(restored.callType, original.callType);
        expect(restored.direction, original.direction);
        expect(restored.status, original.status);
        expect(restored.durationSeconds, original.durationSeconds);
      });

      test('fromJson uses defaults for unknown enum values', () {
        final json = {
          'id': 'id',
          'otherUserId': 'uid',
          'otherUserName': 'name',
          'callType': 'hologram', // invalid
          'direction': 'teleport', // invalid
          'status': 'exploded', // invalid
          'startedAt': '2026-01-01T00:00:00.000',
        };
        final log = CallLog.fromJson(json);
        expect(log.callType, CallType.audio); // default
        expect(log.direction, CallDirection.outgoing); // default
        expect(log.status, CallStatus.completed); // default
      });

      test('fromJson handles missing durationSeconds', () {
        final json = {
          'id': 'id',
          'otherUserId': 'uid',
          'otherUserName': 'name',
          'callType': 'audio',
          'direction': 'incoming',
          'status': 'rejected',
          'startedAt': '2026-01-01T00:00:00.000',
          // durationSeconds intentionally missing
        };
        final log = CallLog.fromJson(json);
        expect(log.durationSeconds, 0);
      });
    });

    group('List encode/decode', () {
      test('encodeList and decodeList roundtrip', () {
        final logs = [
          createSampleLog(),
          CallLog(
            id: 'id-2',
            otherUserId: 'u2',
            otherUserName: 'User 2',
            callType: CallType.video,
            direction: CallDirection.incoming,
            status: CallStatus.missed,
            startedAt: now,
          ),
        ];
        final encoded = CallLog.encodeList(logs);
        expect(encoded, isA<String>());

        final decoded = CallLog.decodeList(encoded);
        expect(decoded.length, 2);
        expect(decoded[0].id, 'test-id-1');
        expect(decoded[1].id, 'id-2');
        expect(decoded[1].callType, CallType.video);
        expect(decoded[1].status, CallStatus.missed);
      });

      test('encodeList with empty list', () {
        final encoded = CallLog.encodeList([]);
        final decoded = CallLog.decodeList(encoded);
        expect(decoded, isEmpty);
      });
    });
  });

  group('CallLog Enums', () {
    test('CallDirection values', () {
      expect(CallDirection.values.length, 2);
      expect(CallDirection.values, contains(CallDirection.incoming));
      expect(CallDirection.values, contains(CallDirection.outgoing));
    });

    test('CallStatus values', () {
      expect(CallStatus.values.length, 3);
      expect(CallStatus.values, contains(CallStatus.completed));
      expect(CallStatus.values, contains(CallStatus.missed));
      expect(CallStatus.values, contains(CallStatus.rejected));
    });

    test('CallType values', () {
      expect(CallType.values.length, 2);
      expect(CallType.values, contains(CallType.audio));
      expect(CallType.values, contains(CallType.video));
    });
  });
}
