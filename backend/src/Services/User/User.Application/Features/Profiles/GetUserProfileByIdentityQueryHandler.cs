using BuildingBlocks.CQRS;
using User.Domain.Entities;
using User.Domain.Interfaces;

namespace User.Application.Features.Profiles
{
    public class GetUserProfileByIdentityQueryHandler : IQueryHandler<GetUserProfileByIdentityQuery, UserProfile?>
    {
        private readonly IUserRepository _userRepository;

        public GetUserProfileByIdentityQueryHandler(IUserRepository userRepository)
        {
            _userRepository = userRepository;
        }

        public async Task<UserProfile?> Handle(GetUserProfileByIdentityQuery request, CancellationToken cancellationToken)
        {
            return await _userRepository.GetByIdentityIdAsync(request.IdentityId);
        }
    }
}
