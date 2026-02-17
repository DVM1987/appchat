using MediatR;
using User.Domain.Entities;
using User.Domain.Interfaces;

namespace User.Application.Features.Profiles
{
using User.Application.DTOs;

    public class GetUserProfileByEmailQueryHandler : IRequestHandler<GetUserProfileByEmailQuery, UserSearchResponse?>
    {
        private readonly IUserRepository _userRepository;
        private readonly IFriendshipRepository _friendshipRepository;

        public GetUserProfileByEmailQueryHandler(IUserRepository userRepository, IFriendshipRepository friendshipRepository)
        {
            _userRepository = userRepository;
            _friendshipRepository = friendshipRepository;
        }

        public async Task<UserSearchResponse?> Handle(GetUserProfileByEmailQuery request, CancellationToken cancellationToken)
        {
            var user = await _userRepository.GetByEmailAsync(request.Email);
            if (user == null) return null;

            var response = new UserSearchResponse
            {
                Id = user.Id,
                IdentityId = user.IdentityId,
                FullName = user.FullName,
                Email = user.Email,
                AvatarUrl = user.AvatarUrl,
                Bio = user.Bio,
                Status = (int)user.Status,
                LastActive = user.LastActive,
                FriendshipStatus = "None"
            };

            if (request.RequesterId.HasValue && request.RequesterId != user.Id)
            {
                var friendship = await _friendshipRepository.GetFriendshipAsync(request.RequesterId.Value, user.Id);
                if (friendship != null)
                {
                    if (friendship.Status == FriendshipStatus.Accepted)
                    {
                        response.FriendshipStatus = "Accepted";
                    }
                    else if (friendship.Status == FriendshipStatus.Pending)
                    {
                        if (friendship.RequesterId == request.RequesterId.Value)
                        {
                            response.FriendshipStatus = "Pending_Sent";
                        }
                        else
                        {
                            response.FriendshipStatus = "Pending_Received";
                        }
                    }
                    else if (friendship.Status == FriendshipStatus.Blocked)
                    {
                        response.FriendshipStatus = "Blocked";
                    }
                }
            }
            else if (request.RequesterId.HasValue && request.RequesterId == user.Id)
            {
                 response.FriendshipStatus = "Self";
            }

            return response;
        }
    }
}
