using BuildingBlocks.CQRS;
using Chat.Domain.Entities;
using Chat.Domain.Interfaces;

namespace Chat.Application.Features.Conversations
{
    public class RemoveParticipantCommandHandler : ICommandHandler<RemoveParticipantCommand, RemoveParticipantResult>
    {
        private readonly IChatRepository _repository;

        public RemoveParticipantCommandHandler(IChatRepository repository)
        {
            _repository = repository;
        }

        public async Task<RemoveParticipantResult> Handle(RemoveParticipantCommand request, CancellationToken cancellationToken)
        {
            var conversation = await _repository.GetConversationAsync(request.ConversationId);
            if (conversation == null) return new RemoveParticipantResult(false);

            // Check if admin
            if (request.AdminId != null && !request.AdminId.Equals(conversation.CreatorId, StringComparison.OrdinalIgnoreCase))
            {
                throw new Exception("Only group creator can remove participants");
            }

            if (!conversation.IsGroup)
            {
                throw new Exception("Cannot remove participants from a 1-1 chat");
            }

            // Cannot remove the creator (for now)
            if (request.ParticipantId == conversation.CreatorId)
            {
                throw new Exception("Cannot remove the group creator");
            }

            if (conversation.ParticipantIds.Remove(request.ParticipantId))
            {
                await _repository.UpdateConversationAsync(conversation);
                
                // Create System Message
                var content = $"{request.ParticipantName} đã bị xóa khỏi nhóm";
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

                Console.WriteLine($"[RemoveParticipant] Removed {request.ParticipantId} from group {request.ConversationId}");
                return new RemoveParticipantResult(true, content);
            }

            return new RemoveParticipantResult(false);
        }
    }
}
