using BuildingBlocks.CQRS;
using Identity.Application.Common.Interfaces;

namespace Identity.Application.Features.Auth
{
    public class SendOtpCommandHandler : ICommandHandler<SendOtpCommand, SendOtpResponse>
    {
        private readonly ISmsVerifyService _smsVerifyService;

        public SendOtpCommandHandler(ISmsVerifyService smsVerifyService)
        {
            _smsVerifyService = smsVerifyService;
        }

        public async Task<SendOtpResponse> Handle(SendOtpCommand request, CancellationToken cancellationToken)
        {
            // Normalize phone number to E.164 format
            var phone = request.PhoneNumber.Trim();
            if (!phone.StartsWith("+"))
                phone = "+84" + phone.TrimStart('0');

            Console.WriteLine($"[OTP] Sending OTP to {phone} via Twilio Verify");

            // Apple Review test account — skip Twilio, OTP is always 123456
            if (phone == "+10000000000")
            {
                Console.WriteLine("[OTP] Test account detected, skipping Twilio");
                return new SendOtpResponse("OTP sent successfully", 300);
            }

            // Send OTP via Twilio Verify SMS
            await _smsVerifyService.SendOtpAsync(phone);

            return new SendOtpResponse("OTP sent successfully", 300);
        }
    }
}
