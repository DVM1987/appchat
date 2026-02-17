import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage locally hidden (deleted) conversations.
/// These conversations are only hidden on the mobile client—they are NOT
/// deleted from the backend database.
class HiddenChatsService {
  static const String _key = 'hidden_chat_ids';

  static HiddenChatsService? _instance;
  factory HiddenChatsService() => _instance ??= HiddenChatsService._();
  HiddenChatsService._();

  Set<String>? _cache;

  /// Synchronous access to cached hidden IDs (may be null if not yet loaded).
  Set<String> get cachedHiddenIds => _cache ?? <String>{};

  /// Load hidden chat IDs from disk. Caches for subsequent calls.
  Future<Set<String>> getHiddenChatIds() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    _cache = list.toSet();
    return _cache!;
  }

  /// Hide one or more conversations locally.
  Future<void> hideChats(Set<String> chatIds) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getHiddenChatIds();
    current.addAll(chatIds);
    _cache = current;
    await prefs.setStringList(_key, current.toList());
  }

  /// Un-hide a conversation (e.g. if the user receives a new message in it).
  Future<void> unhideChat(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getHiddenChatIds();
    current.remove(chatId);
    _cache = current;
    await prefs.setStringList(_key, current.toList());
  }

  /// Check if a specific conversation is hidden.
  Future<bool> isHidden(String chatId) async {
    final hidden = await getHiddenChatIds();
    return hidden.contains(chatId);
  }

  /// Clear all hidden chats (useful for testing/reset).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    _cache = {};
    await prefs.remove(_key);
  }
}
