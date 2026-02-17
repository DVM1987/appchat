using BuildingBlocks.CQRS;

namespace Identity.Application.Features.Auth
{
    public record LoginResponse(string Token, int ExpiresIn);

    public record LoginCommand(string Email, string Password) : ICommand<LoginResponse>;
}
