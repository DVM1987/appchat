using BuildingBlocks.CQRS;
using User.Domain.Entities;
using User.Application.DTOs;

namespace User.Application.Features.Friends
{
    // Returns List of FriendRequestDto
    public record GetPendingRequestsQuery(Guid UserId) : IQuery<List<FriendRequestDto>>;
}
