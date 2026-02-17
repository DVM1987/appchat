using BuildingBlocks.CQRS;
using FluentValidation;

namespace User.Application.Features.Profiles
{
    public record CreateUserProfileCommand(Guid IdentityId, string FullName, string Email) : ICommand<Guid>;

    public class CreateUserProfileCommandValidator : AbstractValidator<CreateUserProfileCommand>
    {
        public CreateUserProfileCommandValidator()
        {
            RuleFor(x => x.IdentityId).NotEmpty();
            RuleFor(x => x.FullName).NotEmpty();
            RuleFor(x => x.Email).NotEmpty().EmailAddress();
        }
    }
}
