import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

class GetConversationsUseCase {
  final ChatRepository repository;

  GetConversationsUseCase(this.repository);

  Future<List<Conversation>> call() async {
    return await repository.getConversations();
  }
}
