using BuildingBlocks.CQRS;
using FluentValidation;

namespace Chat.Application.Features.Conversations
{
    public record LeaveConversationResult(bool Success, string? SystemMessageContent = null);

    public record LeaveConversationCommand(string ConversationId, string UserId, string UserName) : ICommand<LeaveConversationResult>;

    public class LeaveConversationCommandValidator : AbstractValidator<LeaveConversationCommand>
    {
        public LeaveConversationCommandValidator()
        {
            RuleFor(x => x.ConversationId).NotEmpty();
            RuleFor(x => x.UserId).NotEmpty();
            RuleFor(x => x.UserName).NotEmpty();
        }
    }
}
