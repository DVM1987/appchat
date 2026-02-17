using MediatR;

namespace User.Application.Features.Profiles
{
    public class UpdateUserProfileCommand : IRequest<bool>
    {
        public Guid UserId { get; set; }
        public string? FullName { get; set; }
        public string? Bio { get; set; }
        public string? AvatarUrl { get; set; }
    }
}
