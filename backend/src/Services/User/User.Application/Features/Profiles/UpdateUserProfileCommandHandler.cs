using MediatR;
using User.Domain.Interfaces;

namespace User.Application.Features.Profiles
{
    public class UpdateUserProfileCommandHandler : IRequestHandler<UpdateUserProfileCommand, bool>
    {
        private readonly IUserRepository _userRepository;

        public UpdateUserProfileCommandHandler(IUserRepository userRepository)
        {
            _userRepository = userRepository;
        }

        public async Task<bool> Handle(UpdateUserProfileCommand request, CancellationToken cancellationToken)
        {
            var user = await _userRepository.GetByIdentityIdAsync(request.UserId);
            if (user == null) return false;

            // Use existing values if null/empty in request (or handle partial updates)
            var fullName = !string.IsNullOrEmpty(request.FullName) ? request.FullName : user.FullName;
            var bio = request.Bio ?? user.Bio;
            var avatarUrl = !string.IsNullOrEmpty(request.AvatarUrl) ? request.AvatarUrl : user.AvatarUrl;

            user.UpdateProfile(fullName, avatarUrl, bio);

            await _userRepository.UpdateAsync(user);
            return true;
        }
    }
}
