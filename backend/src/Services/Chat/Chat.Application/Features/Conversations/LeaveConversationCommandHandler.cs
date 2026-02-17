using BuildingBlocks.CQRS;
using Chat.Domain.Entities;
using Chat.Domain.Interfaces;

namespace Chat.Application.Features.Conversations
{
    public class LeaveConversationCommandHandler : ICommandHandler<LeaveConversationCommand, LeaveConversationResult>
    {
        private readonly IChatRepository _repository;

        public LeaveConversationCommandHandler(IChatRepository repository)
        {
            _repository = repository;
        }

        public async Task<LeaveConversationResult> Handle(LeaveConversationCommand request, CancellationToken cancellationToken)
        {
            var conversation = await _repository.GetConversationAsync(request.ConversationId);
            if (conversation == null) return new LeaveConversationResult(false);

            if (!conversation.IsGroup)
            {
                throw new Exception("Cannot leave a 1-1 chat");
            }

            // If creator leaves, we might need to assign a new one, but for now let's just 
            // prevent the creator from leaving or require them to disband.
            if (request.UserId.Equals(conversation.CreatorId, StringComparison.OrdinalIgnoreCase))
            {
                throw new Exception("Group creator cannot leave. Please disband the group instead.");
            }

            if (conversation.ParticipantIds.Remove(request.UserId))
            {
                await _repository.UpdateConversationAsync(conversation);
                
                // Create System Message
                var content = $"{request.UserName} đã rời khỏi nhóm";
                var systemMsg = new Message(
                    request.ConversationId, 
                    "system", 
                    content, 
                    MessageType.System
                );
                
                await _repository.SaveMessageAsync(systemMsg);
                
                // Update last message in conversation
                conversation.UpdateLastMessage(systemMsg.Id, content, systemMsg.CreatedAt);
                await _repository.UpdateConversationAsync(conversation);

                Console.WriteLine($"[LeaveConversation] User {request.UserId} left group {request.ConversationId}");
                return new LeaveConversationResult(true, content);
            }

            return new LeaveConversationResult(false);
        }
    }
}
