import '../../core/config/app_config.dart';
import '../../data/models/conversation_model.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../services/chat_service.dart';

class ChatRepositoryImpl implements ChatRepository {
  // For now, using mock data
  // Later will integrate with ChatRemoteDataSource

  final ChatService _chatService = ChatService();

  @override
  Future<List<Conversation>> getConversations() async {
    try {
      final data = await _chatService.getConversations();
      return data.map((json) => ConversationModel.fromJson(json)).toList();
    } catch (e) {
      AppConfig.log('Error verifying conversations: $e');
      return [];
    }
  }

  @override
  Stream<List<Conversation>> watchConversations() {
    // For now, return one-time stream
    // Later will integrate with SignalR
    // For now, return one-time stream
    // Later will integrate with SignalR
    return Stream.value([]);
  }

  @override
  Future<List<Conversation>> searchConversations(String query) async {
    final conversations = await getConversations();
    return conversations
        .where(
          (conv) =>
              conv.name.toLowerCase().contains(query.toLowerCase()) ||
              (conv.lastMessage?.toLowerCase().contains(query.toLowerCase()) ??
                  false),
        )
        .toList();
  }

  @override
  Future<void> archiveConversation(String conversationId) async {
    // TODO: Implement archive logic
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _chatService.disbandConversation(conversationId);
  }
}
