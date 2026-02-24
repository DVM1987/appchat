using BuildingBlocks.CQRS;

namespace Identity.Application.Features.Auth
{
    public record RefreshTokenCommand(string AccessToken, string RefreshToken) : ICommand<RefreshTokenResponse>;

    public record RefreshTokenResponse(string Token, string RefreshToken, int ExpiresIn);
}
