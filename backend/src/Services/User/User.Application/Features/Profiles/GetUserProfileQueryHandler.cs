using BuildingBlocks.CQRS;
using User.Domain.Entities;
using User.Domain.Interfaces;

namespace User.Application.Features.Profiles
{
    public class GetUserProfileQueryHandler : IQueryHandler<GetUserProfileQuery, UserProfile?>
    {
        private readonly IUserRepository _userRepository;

        public GetUserProfileQueryHandler(IUserRepository userRepository)
        {
            _userRepository = userRepository;
        }

        public async Task<UserProfile?> Handle(GetUserProfileQuery request, CancellationToken cancellationToken)
        {
            // Ideally we'd map to a DTO here, but returning Entity for simplicity in MVP
            return await _userRepository.GetByIdAsync(request.UserId); 
        }
    }
}
