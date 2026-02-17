using BuildingBlocks.CQRS;
using Chat.Domain.Entities;
using Chat.Domain.Interfaces;

namespace Chat.Application.Features.Conversations
{
    public class JoinConversationCommandHandler : ICommandHandler<JoinConversationCommand, JoinConversationResult>
    {
        private readonly IChatRepository _repository;

        public JoinConversationCommandHandler(IChatRepository repository)
        {
            _repository = repository;
        }

        public async Task<JoinConversationResult> Handle(JoinConversationCommand request, CancellationToken cancellationToken)
        {
            var conversation = await _repository.GetConversationByInviteTokenAsync(request.InviteToken);
            if (conversation == null) return new JoinConversationResult(false);

            if (conversation.ParticipantIds.Contains(request.UserId))
            {
                // Already in group
                return new JoinConversationResult(true, conversation.Id);
            }

            conversation.ParticipantIds.Add(request.UserId);
            await _repository.UpdateConversationAsync(conversation);
            
            // Create System Message
            var content = $"{request.UserName} đã tham gia nhóm qua liên kết mời";
            var systemMsg = new Message(
                conversation.Id, 
                "system", 
                content, 
                MessageType.System
            );
            
            await _repository.SaveMessageAsync(systemMsg);
            
            // Update last message in conversation
            conversation.UpdateLastMessage(systemMsg.Id, content, systemMsg.CreatedAt);
            await _repository.UpdateConversationAsync(conversation);

            Console.WriteLine($"[JoinConversation] User {request.UserId} joined group {conversation.Id} via token");
            return new JoinConversationResult(true, conversation.Id, content);
        }
    }
}
