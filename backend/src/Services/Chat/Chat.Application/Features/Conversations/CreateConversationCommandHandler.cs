using BuildingBlocks.CQRS;
using Chat.Domain.Entities;
using Chat.Domain.Interfaces;

namespace Chat.Application.Features.Conversations
{
    public class CreateConversationCommandHandler : ICommandHandler<CreateConversationCommand, string>
    {
        private readonly IChatRepository _repository;

        public CreateConversationCommandHandler(IChatRepository repository)
        {
            _repository = repository;
        }

        public async Task<string> Handle(CreateConversationCommand request, CancellationToken cancellationToken)
        {
            // Always sort participants to ensure consistency (A, B) == (B, A)
            var sortedParticipantIds = request.ParticipantIds.OrderBy(x => x).ToList();

            // For Direct Messages (non-group), check if conversation already exists
            if (!request.IsGroup)
            {
                var existing = await _repository.GetConversationByParticipantsAsync(sortedParticipantIds, false);
                if (existing != null)
                {
                    return existing.Id;
                }
            }

            var conversation = new Conversation(sortedParticipantIds, request.IsGroup, request.Name, request.CreatorId);
            await _repository.CreateConversationAsync(conversation);
            return conversation.Id;
        }
    }
}
