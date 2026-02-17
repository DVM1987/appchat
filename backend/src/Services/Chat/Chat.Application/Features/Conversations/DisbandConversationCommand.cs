using BuildingBlocks.CQRS;
using FluentValidation;

namespace Chat.Application.Features.Conversations
{
    public record DisbandConversationResult(bool Success, List<string>? ParticipantIds = null);

    public record DisbandConversationCommand(string ConversationId, string AdminId) : ICommand<DisbandConversationResult>;

    public class DisbandConversationCommandValidator : AbstractValidator<DisbandConversationCommand>
    {
        public DisbandConversationCommandValidator()
        {
            RuleFor(x => x.ConversationId).NotEmpty();
            RuleFor(x => x.AdminId).NotEmpty();
        }
    }
}
