using BuildingBlocks.CQRS;
using User.Domain.Interfaces;
using User.Domain.Entities;

namespace User.Application.Features.Friends
{
    public class DeclineFriendRequestCommandHandler : ICommandHandler<DeclineFriendRequestCommand, bool>
    {
        private readonly IFriendshipRepository _friendshipRepository;
        private readonly IUnitOfWork _unitOfWork;

        public DeclineFriendRequestCommandHandler(IFriendshipRepository friendshipRepository, IUnitOfWork unitOfWork)
        {
            _friendshipRepository = friendshipRepository;
            _unitOfWork = unitOfWork;
        }

        public async Task<bool> Handle(DeclineFriendRequestCommand request, CancellationToken cancellationToken)
        {
            // Find pending request where Requester is FromUserId and Addressee is UserId
            var friendship = await _friendshipRepository.GetFriendshipAsync(request.FromUserId, request.UserId);

            if (friendship == null || friendship.Status != FriendshipStatus.Pending)
            {
                // To be robust, if it's already declined, we could return true, but if accepted, false.
                // Let's return false if not found or not pending.
                return false;
            }

            friendship.Decline();
            
            await _friendshipRepository.UpdateAsync(friendship);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            return true;
        }
    }
}
