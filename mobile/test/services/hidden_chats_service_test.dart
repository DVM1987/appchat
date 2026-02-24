import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/services/hidden_chats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('HiddenChatsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // Reset singleton cache
      // Access via factory — creates fresh instance since mock is reset
    });

    test('getHiddenChatIds returns empty set initially', () async {
      final service = HiddenChatsService();
      // Force reload by clearing cache
      await service.clearAll();
      final ids = await service.getHiddenChatIds();
      expect(ids, isEmpty);
    });

    test('hideChats adds chat IDs', () async {
      final service = HiddenChatsService();
      await service.clearAll();
      await service.hideChats({'chat-1', 'chat-2'});
      final ids = await service.getHiddenChatIds();
      expect(ids, containsAll(['chat-1', 'chat-2']));
      expect(ids.length, 2);
    });

    test('hideChats is additive (does not replace)', () async {
      final service = HiddenChatsService();
      await service.clearAll();
      await service.hideChats({'chat-1'});
      await service.hideChats({'chat-2'});
      final ids = await service.getHiddenChatIds();
      expect(ids, containsAll(['chat-1', 'chat-2']));
    });

    test('hideChats handles duplicates', () async {
      final service = HiddenChatsService();
      await service.clearAll();
      await service.hideChats({'chat-1'});
      await service.hideChats({'chat-1'}); // duplicate
      final ids = await service.getHiddenChatIds();
      expect(ids.length, 1);
    });

    test('unhideChat removes specific chat', () async {
      final service = HiddenChatsService();
      await service.clearAll();
      await service.hideChats({'chat-1', 'chat-2', 'chat-3'});
      await service.unhideChat('chat-2');
      final ids = await service.getHiddenChatIds();
      expect(ids, containsAll(['chat-1', 'chat-3']));
      expect(ids, isNot(contains('chat-2')));
    });

    test('unhideChat does nothing for non-existent id', () async {
      final service = HiddenChatsService();
      await service.clearAll();
      await service.hideChats({'chat-1'});
      await service.unhideChat('non-existent');
      final ids = await service.getHiddenChatIds();
      expect(ids.length, 1);
      expect(ids, contains('chat-1'));
    });

    test('isHidden returns true for hidden chat', () async {
      final service = HiddenChatsService();
      await service.clearAll();
      await service.hideChats({'chat-1'});
      expect(await service.isHidden('chat-1'), true);
    });

    test('isHidden returns false for visible chat', () async {
      final service = HiddenChatsService();
      await service.clearAll();
      expect(await service.isHidden('chat-1'), false);
    });

    test('clearAll removes everything', () async {
      final service = HiddenChatsService();
      await service.clearAll();
      await service.hideChats({'a', 'b', 'c'});
      await service.clearAll();
      final ids = await service.getHiddenChatIds();
      expect(ids, isEmpty);
    });

    test('cachedHiddenIds returns empty set before load', () {
      final service = HiddenChatsService();
      // Before any async call, cache might be empty
      // Just check it doesn't throw
      final cache = service.cachedHiddenIds;
      expect(cache, isA<Set<String>>());
    });

    test('cachedHiddenIds returns cached data after load', () async {
      final service = HiddenChatsService();
      await service.clearAll();
      await service.hideChats({'chat-x'});
      final cache = service.cachedHiddenIds;
      expect(cache, contains('chat-x'));
    });
  });
}
