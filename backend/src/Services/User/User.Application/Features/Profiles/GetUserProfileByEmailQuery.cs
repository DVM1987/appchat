using MediatR;
using User.Domain.Entities;
using User.Application.DTOs;

namespace User.Application.Features.Profiles
{
    public class GetUserProfileByEmailQuery : IRequest<UserSearchResponse?>
    {
        public string Email { get; set; }
        public Guid? RequesterId { get; set; }

        public GetUserProfileByEmailQuery(string email, Guid? requesterId = null)
        {
            Email = email;
            RequesterId = requesterId;
        }
    }
}
