using BuildingBlocks.CQRS;
using User.Application.DTOs;
using User.Domain.Entities;
using User.Domain.Interfaces;

namespace User.Application.Features.Friends
{
    public class GetPendingRequestsQueryHandler : IQueryHandler<GetPendingRequestsQuery, List<FriendRequestDto>>
    {
        private readonly IFriendshipRepository _friendshipRepository;
        private readonly IUserRepository _userRepository;

        public GetPendingRequestsQueryHandler(IFriendshipRepository friendshipRepository, IUserRepository userRepository)
        {
            _friendshipRepository = friendshipRepository;
            _userRepository = userRepository;
        }

        public async Task<List<FriendRequestDto>> Handle(GetPendingRequestsQuery request, CancellationToken cancellationToken)
        {
            var pendingFriendships = await _friendshipRepository.GetPendingRequestsAsync(request.UserId);
            
            if (!pendingFriendships.Any())
                return new List<FriendRequestDto>();

            var requesterIds = pendingFriendships.Select(f => f.RequesterId).Distinct().ToList();
            var profiles = await _userRepository.GetByIdsAsync(requesterIds);
            var profilesDict = profiles.ToDictionary(p => p.Id);

            var result = new List<FriendRequestDto>();
            foreach (var friendship in pendingFriendships)
            {
                if (profilesDict.TryGetValue(friendship.RequesterId, out var profile))
                {
                    result.Add(new FriendRequestDto(
                        friendship.Id,
                        new FriendDto(profile.Id, profile.IdentityId, profile.FullName, profile.Email, profile.AvatarUrl),
                        friendship.CreatedAt,
                        friendship.Status.ToString()
                    ));
                }
            }

            return result;
        }
    }
}
