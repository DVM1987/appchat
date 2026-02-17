using BuildingBlocks.CQRS;
using FluentValidation;

namespace Chat.Application.Features.Conversations
{
    public record CreateConversationCommand(List<string> ParticipantIds, string? Name, bool IsGroup, string? CreatorId = null) : ICommand<string>;

    public class CreateConversationCommandValidator : AbstractValidator<CreateConversationCommand>
    {
        public CreateConversationCommandValidator()
        {
            RuleFor(x => x.ParticipantIds).NotEmpty().Must(x => x.Count > 0).WithMessage("At least one participant required.");
            // If IsGroup is true, Name should probably be required or default handled
        }
    }
}
