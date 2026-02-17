using BuildingBlocks.CQRS;
using FluentValidation;

namespace Chat.Application.Features.Conversations;

public record UpdateConversationResult(bool Success, string? SystemMessageContent = null, string? ErrorMessage = null);

public record UpdateConversationCommand(string ConversationId, string? Name, string? Description, string? AvatarUrl, string UpdatedBy, string UpdatedByName) : ICommand<UpdateConversationResult>;

public class UpdateConversationCommandValidator : AbstractValidator<UpdateConversationCommand>
{
    public UpdateConversationCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.UpdatedBy).NotEmpty();
    }
}
