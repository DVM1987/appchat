using BuildingBlocks.CQRS;
using User.Application.DTOs;
using User.Domain.Entities;
using User.Domain.Interfaces;

namespace User.Application.Features.Friends
{
    public class GetFriendsQueryHandler : IQueryHandler<GetFriendsQuery, List<FriendDto>>
    {
        private readonly IFriendshipRepository _friendshipRepository;
        private readonly IUserRepository _userRepository;

        public GetFriendsQueryHandler(IFriendshipRepository friendshipRepository, IUserRepository userRepository)
        {
            _friendshipRepository = friendshipRepository;
            _userRepository = userRepository;
        }

        public async Task<List<FriendDto>> Handle(GetFriendsQuery request, CancellationToken cancellationToken)
        {
            var friendships = await _friendshipRepository.GetFriendshipsByUserIdAsync(request.UserId);
            
            if (!friendships.Any())
                return new List<FriendDto>();

            // Identify Friend IDs
            var friendIds = friendships.Select(f => 
                f.RequesterId == request.UserId ? f.AddresseeId : f.RequesterId
            ).Distinct().ToList();

            var profiles = await _userRepository.GetByIdsAsync(friendIds);
            
            // Map to DTOs
            return profiles.Select(p => new FriendDto(
                p.Id,
                p.IdentityId,
                p.FullName,
                p.Email,
                p.AvatarUrl
            )).ToList();
        }
    }
}
