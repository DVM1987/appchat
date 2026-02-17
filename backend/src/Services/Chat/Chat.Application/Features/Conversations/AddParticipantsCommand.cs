using BuildingBlocks.CQRS;
using FluentValidation;

namespace Chat.Application.Features.Conversations
{
    public record AddParticipantsResult(bool Success, string? SystemMessageContent = null);

    public record AddParticipantsCommand(string ConversationId, List<string> ParticipantIds, List<string>? ParticipantNames = null, string? AdminId = null) : ICommand<AddParticipantsResult>;

    public class AddParticipantsCommandValidator : AbstractValidator<AddParticipantsCommand>
    {
        public AddParticipantsCommandValidator()
        {
            RuleFor(x => x.ConversationId).NotEmpty();
            RuleFor(x => x.ParticipantIds).NotEmpty();
        }
    }
}
