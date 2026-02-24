import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/models/conversation_model.dart';
import 'package:mobile/domain/entities/conversation.dart';

void main() {
  group('ConversationModel', () {
    group('fromJson', () {
      test('parses minimal required fields', () {
        final json = {'id': 'conv-1', 'name': 'Test Chat'};
        final model = ConversationModel.fromJson(json);
        expect(model.id, 'conv-1');
        expect(model.name, 'Test Chat');
        expect(model.avatarUrl, isNull);
        expect(model.lastMessage, isNull);
        expect(model.lastMessageTime, isNull);
        expect(model.isOnline, false);
        expect(model.unreadCount, 0);
        expect(model.isArchived, false);
        expect(model.isPinned, false);
        expect(model.isGroup, false);
        expect(model.participantIds, isEmpty);
      });

      test('parses name defaults to "Chat" when null', () {
        final json = {'id': 'conv-1', 'name': null};
        final model = ConversationModel.fromJson(json);
        expect(model.name, 'Chat');
      });

      test('parses all fields correctly', () {
        final json = {
          'id': 'conv-full',
          'name': 'Full Chat',
          'avatarUrl': 'https://example.com/avatar.png',
          'lastMessage': 'Hello!',
          'lastMessageTime': '2026-02-24T10:00:00Z',
          'lastMessageType': 'text',
          'isOnline': true,
          'unreadCount': 5,
          'isArchived': false,
          'isPinned': true,
          'isGroup': true,
          'hasCheckmark': true,
          'voiceNoteDuration': 14,
          'participantIds': ['user1', 'user2', 'user3'],
          'creatorId': 'user1',
          'description': 'A test group',
        };
        final model = ConversationModel.fromJson(json);
        expect(model.id, 'conv-full');
        expect(model.name, 'Full Chat');
        expect(model.avatarUrl, 'https://example.com/avatar.png');
        expect(model.lastMessage, 'Hello!');
        expect(model.lastMessageTime, isNotNull);
        expect(model.lastMessageType, MessageType.text);
        expect(model.isOnline, true);
        expect(model.unreadCount, 5);
        expect(model.isPinned, true);
        expect(model.isGroup, true);
        expect(model.hasCheckmark, true);
        expect(model.voiceNoteDuration, const Duration(seconds: 14));
        expect(model.participantIds, ['user1', 'user2', 'user3']);
        expect(model.creatorId, 'user1');
        expect(model.description, 'A test group');
      });

      test('parses MessageType variants', () {
        for (final type in ['text', 'photo', 'voice', 'video', 'file']) {
          final json = {'id': 'id', 'name': 'name', 'lastMessageType': type};
          final model = ConversationModel.fromJson(json);
          expect(model.lastMessageType, isNotNull);
          expect(model.lastMessageType!.name, type);
        }
      });

      test('falls back to text for unknown MessageType', () {
        final json = {
          'id': 'id',
          'name': 'name',
          'lastMessageType': 'hologram',
        };
        final model = ConversationModel.fromJson(json);
        expect(model.lastMessageType, MessageType.text);
      });
    });

    group('UTC DateTime parsing', () {
      test('parses ISO8601 with Z suffix correctly', () {
        final json = {
          'id': 'id',
          'name': 'name',
          'lastMessageTime': '2026-02-24T10:00:00Z',
        };
        final model = ConversationModel.fromJson(json);
        expect(model.lastMessageTime, isNotNull);
        // Should be converted to local time
        expect(model.lastMessageTime!.isUtc, false);
      });

      test('parses ISO8601 without timezone as UTC', () {
        final json = {
          'id': 'id',
          'name': 'name',
          'lastMessageTime': '2026-02-24T10:00:00',
        };
        final model = ConversationModel.fromJson(json);
        expect(model.lastMessageTime, isNotNull);
        expect(model.lastMessageTime!.isUtc, false); // converted to local
      });

      test('handles null lastMessageTime', () {
        final json = {'id': 'id', 'name': 'name'};
        final model = ConversationModel.fromJson(json);
        expect(model.lastMessageTime, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final model = ConversationModel(
          id: 'conv-1',
          name: 'Test',
          isGroup: true,
          participantIds: const ['a', 'b'],
          creatorId: 'a',
          description: 'desc',
          unreadCount: 3,
          lastMessage: 'Hi',
        );
        final json = model.toJson();
        expect(json['id'], 'conv-1');
        expect(json['name'], 'Test');
        expect(json['isGroup'], true);
        expect(json['participantIds'], ['a', 'b']);
        expect(json['creatorId'], 'a');
        expect(json['description'], 'desc');
        expect(json['unreadCount'], 3);
        expect(json['lastMessage'], 'Hi');
      });

      test('roundtrip: toJson → fromJson', () {
        final original = ConversationModel(
          id: 'conv-rt',
          name: 'Roundtrip',
          isGroup: false,
          participantIds: const ['u1', 'u2'],
          unreadCount: 10,
          lastMessage: 'Test message',
        );
        final json = original.toJson();
        final restored = ConversationModel.fromJson(json);
        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.isGroup, original.isGroup);
        expect(restored.participantIds, original.participantIds);
        expect(restored.unreadCount, original.unreadCount);
        expect(restored.lastMessage, original.lastMessage);
      });
    });

    group('Equatable', () {
      test('two conversations with same data are equal', () {
        const c1 = Conversation(id: '1', name: 'A');
        const c2 = Conversation(id: '1', name: 'A');
        expect(c1, equals(c2));
      });

      test('two conversations with different id are not equal', () {
        const c1 = Conversation(id: '1', name: 'A');
        const c2 = Conversation(id: '2', name: 'A');
        expect(c1, isNot(equals(c2)));
      });
    });

    group('Conversation copyWith', () {
      test('copies with changed fields', () {
        const original = Conversation(
          id: '1',
          name: 'Original',
          unreadCount: 5,
          isOnline: false,
        );
        final copy = original.copyWith(
          name: 'Updated',
          unreadCount: 0,
          isOnline: true,
        );
        expect(copy.id, '1');
        expect(copy.name, 'Updated');
        expect(copy.unreadCount, 0);
        expect(copy.isOnline, true);
      });

      test('preserves all fields when no arguments', () {
        const original = Conversation(
          id: '1',
          name: 'Test',
          isGroup: true,
          participantIds: ['a'],
        );
        final copy = original.copyWith();
        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.isGroup, original.isGroup);
        expect(copy.participantIds, original.participantIds);
      });
    });
  });
}
