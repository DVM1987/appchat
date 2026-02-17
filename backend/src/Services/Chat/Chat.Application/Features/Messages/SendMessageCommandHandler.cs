using BuildingBlocks.CQRS;
using Chat.Domain.Entities;
using Chat.Domain.Interfaces;

namespace Chat.Application.Features.Messages
{
    public class SendMessageCommandHandler : ICommandHandler<SendMessageCommand, string>
    {
        private readonly IChatRepository _repository;

        public SendMessageCommandHandler(IChatRepository repository)
        {
            _repository = repository;
        }

        public async Task<string> Handle(SendMessageCommand request, CancellationToken cancellationToken)
        {
            var conversation = await _repository.GetConversationAsync(request.ConversationId);
            if (conversation == null)
            {
                throw new Exception("Conversation not found or has been disbanded");
            }

            if (!conversation.ParticipantIds.Contains(request.SenderId))
            {
                throw new Exception("You are no longer a participant in this conversation");
            }

            var message = new Message(
                request.ConversationId,
                request.SenderId,
                request.Content,
                (MessageType)request.Type,
                request.ReplyToId,
                request.ReplyToContent
            );

            await _repository.SaveMessageAsync(message);
            
            // Also update conversation last message
            var lastMessageContent = message.Type switch
            {
                MessageType.Image => "📷 Ảnh",
                MessageType.Voice => "🎤 Voice",
                _ => message.Content
            };
            conversation.UpdateLastMessage(message.Id, lastMessageContent, message.CreatedAt);
            await _repository.UpdateConversationAsync(conversation);
            
            // Should publish event for SignalR here? 
            // Better to do it in Controller or via MediatR Notification.
            // But for simplicity, we'll let Controller handle signalR broadcast after this command succeeds.

            return message.Id;
        }
    }
}
