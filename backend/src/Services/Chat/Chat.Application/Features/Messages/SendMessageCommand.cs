using BuildingBlocks.CQRS;

namespace Chat.Application.Features.Messages
{
    public record SendMessageCommand(string ConversationId, string SenderId, string Content, int Type, string? ReplyToId = null, string? ReplyToContent = null) : ICommand<string>;
    // Type: 0=Text, 1=Image, 2=File, 3=System, 4=Voice
}
