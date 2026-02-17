using BuildingBlocks.CQRS;

namespace User.Application.Features.Friends
{
    public record AcceptFriendRequestCommand(Guid RequesterId, Guid AddresseeId) : ICommand<bool>;
}
