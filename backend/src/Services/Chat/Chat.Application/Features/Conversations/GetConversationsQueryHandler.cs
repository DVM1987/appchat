using BuildingBlocks.CQRS;
using Chat.Domain.Entities;
using Chat.Domain.Interfaces;

namespace Chat.Application.Features.Conversations
{
    public class GetConversationsQueryHandler : IQueryHandler<GetConversationsQuery, List<ConversationDto>>
    {
        private readonly IChatRepository _repository;

        public GetConversationsQueryHandler(IChatRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<ConversationDto>> Handle(GetConversationsQuery request, CancellationToken cancellationToken)
        {
            var conversations = await _repository.GetConversationsByUserIdAsync(request.UserId);
            var dtos = new List<ConversationDto>();

            foreach (var c in conversations)
            {
                // Logic: Only show conversations that have at least one message OR are groups
                // Empty 1-1 chats are hidden until first message
                if (string.IsNullOrEmpty(c.LastMessageContent) && !c.IsGroup)
                {
                    continue;
                }

                var unreadCount = await _repository.GetUnreadMessageCountAsync(c.Id, request.UserId);
                dtos.Add(new ConversationDto
                {
                    Id = c.Id,
                    Name = c.Name,
                    IsGroup = c.IsGroup,
                    ParticipantIds = c.ParticipantIds,
                    CreatorId = c.CreatorId ?? c.ParticipantIds.FirstOrDefault(),
                    Description = c.Description,
                    LastMessage = c.LastMessageContent,
                    LastMessageTime = c.LastMessageTime ?? c.CreatedAt,
                    UnreadCount = unreadCount
                });
            }

            return dtos.OrderByDescending(x => x.LastMessageTime).ToList();
        }
    }
}
