using BuildingBlocks.CQRS;
using Chat.Domain.Entities;

namespace Chat.Application.Features.Messages
{
    public record GetMessagesQuery(string ConversationId, string UserId, int Skip, int Take) : IQuery<List<Message>>;
}
