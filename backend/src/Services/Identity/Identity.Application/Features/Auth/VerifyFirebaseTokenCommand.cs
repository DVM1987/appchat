using BuildingBlocks.CQRS;

namespace Identity.Application.Features.Auth
{
    public record VerifyFirebaseTokenCommand(string IdToken, string? FullName) : ICommand<VerifyFirebaseTokenResponse>;

    public record VerifyFirebaseTokenResponse(string Token, string RefreshToken, int ExpiresIn, bool IsNewUser);
}
