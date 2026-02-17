using BuildingBlocks.CQRS;
using User.Domain.Entities;
using User.Application.DTOs;

namespace User.Application.Features.Friends
{
    // Returns List of FriendDto
    public record GetFriendsQuery(Guid UserId) : IQuery<List<FriendDto>>;
}
