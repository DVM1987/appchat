using BuildingBlocks.CQRS;

namespace Identity.Application.Features.Auth
{
    public record VerifyOtpCommand(string PhoneNumber, string OtpCode, string? FullName) : ICommand<VerifyOtpResponse>;

    public record VerifyOtpResponse(string Token, int ExpiresIn, bool IsNewUser);
}
