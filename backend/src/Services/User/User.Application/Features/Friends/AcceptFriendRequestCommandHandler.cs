using BuildingBlocks.CQRS;
using User.Domain.Entities;
using User.Domain.Interfaces;

namespace User.Application.Features.Friends
{
    public class AcceptFriendRequestCommandHandler : ICommandHandler<AcceptFriendRequestCommand, bool>
    {
        private readonly IFriendshipRepository _friendshipRepository;
        private readonly IUnitOfWork _unitOfWork;

        public AcceptFriendRequestCommandHandler(IFriendshipRepository friendshipRepository, IUnitOfWork unitOfWork)
        {
            _friendshipRepository = friendshipRepository;
            _unitOfWork = unitOfWork;
        }

        public async Task<bool> Handle(AcceptFriendRequestCommand request, CancellationToken cancellationToken)
        {
            // Note: In Command, RequesterId is the one who SENT the request. AddresseeId is the one ACCEPTING (current user).
            
            var friendship = await _friendshipRepository.GetFriendshipAsync(request.RequesterId, request.AddresseeId);
            if (friendship == null || friendship.Status != FriendshipStatus.Pending)
            {
                return false;
            }

            // Ensure the one accepting is indeed the Addressee
            if (friendship.AddresseeId != request.AddresseeId)
            {
                return false;
            }

            friendship.Accept();
            await _friendshipRepository.UpdateAsync(friendship);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            return true;
        }
    }
}
