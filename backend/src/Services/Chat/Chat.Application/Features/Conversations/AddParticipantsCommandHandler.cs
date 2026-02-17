using BuildingBlocks.CQRS;
using Chat.Domain.Entities;
using Chat.Domain.Interfaces;

namespace Chat.Application.Features.Conversations
{
    public class AddParticipantsCommandHandler : ICommandHandler<AddParticipantsCommand, AddParticipantsResult>
    {
        private readonly IChatRepository _repository;

        public AddParticipantsCommandHandler(IChatRepository repository)
        {
            _repository = repository;
        }

        public async Task<AddParticipantsResult> Handle(AddParticipantsCommand request, CancellationToken cancellationToken)
        {
            var conversation = await _repository.GetConversationAsync(request.ConversationId);
            if (conversation == null) return new AddParticipantsResult(false);

            // Optional: Check if admin
            if (request.AdminId != null && conversation.CreatorId != request.AdminId)
            {
                throw new Exception("Only group creator can add participants");
            }

            if (!conversation.IsGroup)
            {
                throw new Exception("Cannot add participants to a 1-1 chat");
            }

            var existingIds = conversation.ParticipantIds.ToHashSet();
            bool changed = false;

            foreach (var id in request.ParticipantIds)
            {
                if (existingIds.Add(id))
                {
                    conversation.ParticipantIds.Add(id);
                    changed = true;
                }
            }

            if (changed)
            {
                await _repository.UpdateConversationAsync(conversation);
                
                // Create System Message
                var names = request.ParticipantNames != null && request.ParticipantNames.Any() 
                    ? string.Join(", ", request.ParticipantNames)
                    : "Thành viên mới";
                
                var content = $"{names} đã được thêm vào nhóm";
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

                Console.WriteLine($"[AddParticipants] Added {request.ParticipantIds.Count} participants to group {request.ConversationId}");
                return new AddParticipantsResult(true, content);
            }

            return new AddParticipantsResult(true);
        }
    }
}
