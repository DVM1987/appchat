using BuildingBlocks.CQRS;
using Chat.Domain.Entities;
using Chat.Domain.Interfaces;

namespace Chat.Application.Features.Messages
{
    public class GetMessagesQueryHandler : IQueryHandler<GetMessagesQuery, List<Message>>
    {
        private readonly IChatRepository _repository;

        public GetMessagesQueryHandler(IChatRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<Message>> Handle(GetMessagesQuery request, CancellationToken cancellationToken)
        {
            var conversation = await _repository.GetConversationAsync(request.ConversationId);
            if (conversation == null)
            {
                return new List<Message>();
            }
            return await _repository.GetMessagesAsync(request.ConversationId, request.UserId, request.Skip, request.Take);
        }
    }
}
