using BuildingBlocks.CQRS;
using FluentValidation;

namespace User.Application.Features.Friends
{
    public record SendFriendRequestCommand(Guid RequesterId, Guid AddresseeId) : ICommand<bool>;

    public class SendFriendRequestCommandValidator : AbstractValidator<SendFriendRequestCommand>
    {
        public SendFriendRequestCommandValidator()
        {
            RuleFor(x => x.RequesterId).NotEmpty();
            RuleFor(x => x.AddresseeId).NotEmpty();
            RuleFor(x => x).Must(x => x.RequesterId != x.AddresseeId).WithMessage("Cannot send friend request to self.");
        }
    }
}
