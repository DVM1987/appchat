using BuildingBlocks.CQRS;
using FluentValidation;

namespace Identity.Application.Features.Auth
{
    public record RegisterUserCommand(string Email, string Password, string FullName) : ICommand<Guid>;

    public class RegisterUserCommandValidator : AbstractValidator<RegisterUserCommand>
    {
        public RegisterUserCommandValidator()
        {
            RuleFor(x => x.Email).NotEmpty().EmailAddress();
            RuleFor(x => x.Password).NotEmpty().MinimumLength(6);
            RuleFor(x => x.FullName).NotEmpty();
        }
    }
}
