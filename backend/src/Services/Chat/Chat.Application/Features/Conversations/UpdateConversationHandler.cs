using BuildingBlocks.CQRS;
using Chat.Domain.Interfaces;
using Chat.Domain.Entities;
using MediatR; // Ensure ICommandHandler is recognized if not in BuildingBlocks

namespace Chat.Application.Features.Conversations;

public class UpdateConversationCommandHandler : ICommandHandler<UpdateConversationCommand, UpdateConversationResult>
{
    private readonly IChatRepository _repository;

    public UpdateConversationCommandHandler(IChatRepository repository)
    {
        _repository = repository;
    }

    public async Task<UpdateConversationResult> Handle(UpdateConversationCommand command, CancellationToken cancellationToken)
    {
        var conversation = await _repository.GetConversationAsync(command.ConversationId);
        if (conversation == null)
            return new UpdateConversationResult(false, null, "Conversation not found");

        if (conversation.IsGroup && conversation.CreatorId != command.UpdatedBy)
            return new UpdateConversationResult(false, null, "Only the group creator can update group info");

        var changes = new List<string>();

        if (!string.IsNullOrEmpty(command.Name) && command.Name != conversation.Name)
        {
            changes.Add($"đổi tên nhóm thành \"{command.Name}\"");
        }

        if (command.Description != null && command.Description != conversation.Description)
        {
            changes.Add("cập nhật mô tả nhóm");
        }

        if (command.AvatarUrl != null && command.AvatarUrl != conversation.AvatarUrl)
        {
            changes.Add("cập nhật ảnh đại diện nhóm");
        }

        if (changes.Count > 0)
        {
            conversation.UpdateInfo(command.Name, command.Description, command.AvatarUrl);
            await _repository.UpdateConversationAsync(conversation);
            var systemMessage = $"{command.UpdatedByName} đã {string.Join(", ", changes)}.";
            return new UpdateConversationResult(true, systemMessage);
        }

        return new UpdateConversationResult(true, null); // No changes made
    }
}
