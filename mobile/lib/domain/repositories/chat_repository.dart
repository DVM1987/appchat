import '../entities/conversation.dart';

abstract class ChatRepository {
  /// Get all conversations
  Future<List<Conversation>> getConversations();

  /// Watch conversations stream (for real-time updates)
  Stream<List<Conversation>> watchConversations();

  /// Search conversations by name or message
  Future<List<Conversation>> searchConversations(String query);

  /// Archive a conversation
  Future<void> archiveConversation(String conversationId);

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId);
}
