using BuildingBlocks.CQRS;
using FluentValidation;

namespace Chat.Application.Features.Conversations
{
    public record JoinConversationResult(bool Success, string? ConversationId = null, string? SystemMessageContent = null);

    public record JoinConversationCommand(string InviteToken, string UserId, string UserName) : ICommand<JoinConversationResult>;

    public class JoinConversationCommandValidator : AbstractValidator<JoinConversationCommand>
    {
        public JoinConversationCommandValidator()
        {
            RuleFor(x => x.InviteToken).NotEmpty();
            RuleFor(x => x.UserId).NotEmpty();
            RuleFor(x => x.UserName).NotEmpty();
        }
    }
}
