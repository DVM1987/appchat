using BuildingBlocks.CQRS;
using User.Domain.Entities;
using User.Domain.Interfaces;

namespace User.Application.Features.Friends
{
    public class SendFriendRequestCommandHandler : ICommandHandler<SendFriendRequestCommand, bool>
    {
        private readonly IFriendshipRepository _friendshipRepository;
        private readonly IUnitOfWork _unitOfWork;

        public SendFriendRequestCommandHandler(IFriendshipRepository friendshipRepository, IUnitOfWork unitOfWork)
        {
            _friendshipRepository = friendshipRepository;
            _unitOfWork = unitOfWork;
        }

        public async Task<bool> Handle(SendFriendRequestCommand request, CancellationToken cancellationToken)
        {
            var existing = await _friendshipRepository.GetFriendshipAsync(request.RequesterId, request.AddresseeId);
            if (existing != null)
            {
                if (existing.Status == FriendshipStatus.Declined)
                {
                    existing.Reset(request.RequesterId, request.AddresseeId);
                    await _friendshipRepository.UpdateAsync(existing);
                    await _unitOfWork.SaveChangesAsync(cancellationToken);
                    return true;
                }

                // Already friends or pending
                return false; 
            }

            var friendship = new Friendship(request.RequesterId, request.AddresseeId);
            await _friendshipRepository.AddAsync(friendship);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            return true;
        }
    }
}
