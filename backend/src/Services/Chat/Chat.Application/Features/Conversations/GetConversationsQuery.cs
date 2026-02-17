using BuildingBlocks.CQRS;
using Chat.Domain.Entities;

namespace Chat.Application.Features.Conversations
{
    public record GetConversationsQuery(string UserId) : IQuery<List<ConversationDto>>;
}
