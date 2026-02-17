using MediatR;

namespace Chat.Application.Features.Messages
{
    public record ReactToMessageCommand(string MessageId, string UserId, string ReactionType) : IRequest;
}
