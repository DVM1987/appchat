using BuildingBlocks.CQRS;

namespace User.Application.Features.Friends
{
    public record DeclineFriendRequestCommand(Guid UserId, Guid FromUserId) : ICommand<bool>;
}
