using BuildingBlocks.CQRS;
using User.Domain.Entities;

namespace User.Application.Features.Profiles
{
    public record GetUserProfileQuery(Guid UserId) : IQuery<UserProfile?>;
}
