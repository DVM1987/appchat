using BuildingBlocks.CQRS;
using User.Domain.Entities;

namespace User.Application.Features.Profiles
{
    public record GetUserProfileByIdentityQuery(Guid IdentityId) : IQuery<UserProfile?>;
}
