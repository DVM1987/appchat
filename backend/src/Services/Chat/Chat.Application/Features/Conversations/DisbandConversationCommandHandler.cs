using BuildingBlocks.CQRS;
using Chat.Domain.Interfaces;

namespace Chat.Application.Features.Conversations
{
    public class DisbandConversationCommandHandler : ICommandHandler<DisbandConversationCommand, DisbandConversationResult>
    {
        private readonly IChatRepository _repository;

        public DisbandConversationCommandHandler(IChatRepository repository)
        {
            _repository = repository;
        }

        public async Task<DisbandConversationResult> Handle(DisbandConversationCommand request, CancellationToken cancellationToken)
        {
            var conversation = await _repository.GetConversationAsync(request.ConversationId);
            if (conversation == null) return new DisbandConversationResult(false);

            if (!request.AdminId.Equals(conversation.CreatorId, StringComparison.OrdinalIgnoreCase))
            {
                throw new Exception("Only the group creator can disband the group.");
            }

            var participants = conversation.ParticipantIds.ToList();

            // Delete conversation and messages
            await _repository.DeleteConversationAsync(request.ConversationId);
            await _repository.DeleteMessagesByConversationIdAsync(request.ConversationId);

            Console.WriteLine($"[DisbandConversation] Group {request.ConversationId} disbanded by {request.AdminId}");
            return new DisbandConversationResult(true, participants);
        }
    }
}
