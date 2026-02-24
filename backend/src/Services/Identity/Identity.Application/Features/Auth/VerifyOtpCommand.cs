using BuildingBlocks.CQRS;

namespace Identity.Application.Features.Auth
{
    public record VerifyOtpCommand(string PhoneNumber, string OtpCode, string? FullName) : ICommand<VerifyOtpResponse>;

    public record VerifyOtpResponse(string Token, string RefreshToken, int ExpiresIn, bool IsNewUser);
}
