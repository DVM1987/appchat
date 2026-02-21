using BuildingBlocks.CQRS;
using Identity.Application.Common.Interfaces;
using Identity.Domain.Entities;

namespace Identity.Application.Features.Auth
{
    public class SendOtpCommandHandler : ICommandHandler<SendOtpCommand, SendOtpResponse>
    {
        private readonly IOtpRepository _otpRepository;

        public SendOtpCommandHandler(IOtpRepository otpRepository)
        {
            _otpRepository = otpRepository;
        }

        public async Task<SendOtpResponse> Handle(SendOtpCommand request, CancellationToken cancellationToken)
        {
            // Normalize phone number
            var phone = request.PhoneNumber.Trim();
            if (!phone.StartsWith("+"))
                phone = "+84" + phone.TrimStart('0');

            // Dev Mode: OTP is always 123456
            // In production, replace with Twilio/Firebase SMS send
            var otpCode = "123456";

            var otp = new OtpEntry(phone, otpCode, ttlSeconds: 300); // 5 minutes
            await _otpRepository.SaveAsync(otp);

            Console.WriteLine($"[OTP] Generated OTP for {phone}: {otpCode}");

            return new SendOtpResponse("OTP sent successfully", 300);
        }
    }
}
