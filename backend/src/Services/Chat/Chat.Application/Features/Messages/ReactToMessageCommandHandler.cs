using MediatR;
using Chat.Domain.Interfaces;
using Chat.Domain.Entities;

namespace Chat.Application.Features.Messages
{
    public class ReactToMessageCommandHandler : IRequestHandler<ReactToMessageCommand>
    {
        private readonly IChatRepository _repository;

        public ReactToMessageCommandHandler(IChatRepository repository)
        {
            _repository = repository;
        }

        public async Task Handle(ReactToMessageCommand request, CancellationToken cancellationToken)
        {
            var message = await _repository.GetMessageAsync(request.MessageId);
            if (message == null)
            {
                // In a real app, maybe throw specific exception
                return;
            }

            message.AddReaction(request.UserId, request.ReactionType);
            await _repository.UpdateMessageAsync(message);
        }
    }
}
