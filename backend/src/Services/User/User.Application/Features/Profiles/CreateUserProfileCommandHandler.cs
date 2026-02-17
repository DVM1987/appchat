using BuildingBlocks.CQRS;
using User.Domain.Entities;
using User.Domain.Interfaces;

namespace User.Application.Features.Profiles
{
    public class CreateUserProfileCommandHandler : ICommandHandler<CreateUserProfileCommand, Guid>
    {
        private readonly IUserRepository _userRepository;
        private readonly IUnitOfWork _unitOfWork;

        public CreateUserProfileCommandHandler(IUserRepository userRepository, IUnitOfWork unitOfWork)
        {
            _userRepository = userRepository;
            _unitOfWork = unitOfWork;
        }

        public async Task<Guid> Handle(CreateUserProfileCommand request, CancellationToken cancellationToken)
        {
            if (await _userRepository.ExistsAsync(request.IdentityId))
            {
                // Already exists, maybe return existing ID or throw?
                // For idempotency, let's return existing if found
                var existing = await _userRepository.GetByIdentityIdAsync(request.IdentityId);
                return existing!.Id;
            }

            var profile = new UserProfile(request.IdentityId, request.FullName, request.Email);
            await _userRepository.CreateAsync(profile);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            return profile.Id;
        }
    }
}
