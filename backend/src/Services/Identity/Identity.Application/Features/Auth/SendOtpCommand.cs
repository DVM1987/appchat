using BuildingBlocks.CQRS;

namespace Identity.Application.Features.Auth
{
    public record SendOtpCommand(string PhoneNumber) : ICommand<SendOtpResponse>;

    public record SendOtpResponse(string Message, int ExpiresIn);
}
