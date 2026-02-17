using BuildingBlocks.CQRS;
using FluentValidation;

namespace Chat.Application.Features.Conversations
{
    public record RemoveParticipantResult(bool Success, string? SystemMessageContent = null);

    public record RemoveParticipantCommand(string ConversationId, string ParticipantId, string ParticipantName, string? AdminId = null) : ICommand<RemoveParticipantResult>;

    public class RemoveParticipantCommandValidator : AbstractValidator<RemoveParticipantCommand>
    {
        public RemoveParticipantCommandValidator()
        {
            RuleFor(x => x.ConversationId).NotEmpty();
            RuleFor(x => x.ParticipantId).NotEmpty();
            RuleFor(x => x.ParticipantName).NotEmpty();
        }
    }
}
