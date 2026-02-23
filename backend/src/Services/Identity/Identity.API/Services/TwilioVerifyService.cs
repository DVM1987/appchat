using Identity.Application.Common.Interfaces;
using Microsoft.Extensions.Configuration;
using Twilio;
using Twilio.Rest.Verify.V2.Service;

namespace Identity.API.Services
{
    public class TwilioVerifyService : ISmsVerifyService
    {
        private readonly string _serviceSid;

        public TwilioVerifyService(IConfiguration config)
        {
            var accountSid = config["Twilio:AccountSid"]
                ?? throw new InvalidOperationException("Twilio:AccountSid is missing");
            var authToken = config["Twilio:AuthToken"]
                ?? throw new InvalidOperationException("Twilio:AuthToken is missing");
            _serviceSid = config["Twilio:VerifyServiceSid"]
                ?? throw new InvalidOperationException("Twilio:VerifyServiceSid is missing");

            TwilioClient.Init(accountSid, authToken);
        }

        public async Task<bool> SendOtpAsync(string phoneNumber)
        {
            try
            {
                var verification = await VerificationResource.CreateAsync(
                    to: phoneNumber,
                    channel: "sms",
                    pathServiceSid: _serviceSid
                );

                Console.WriteLine($"[Twilio] OTP sent to {phoneNumber}: status={verification.Status}");
                return verification.Status == "pending";
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Twilio] Failed to send OTP to {phoneNumber}: {ex.Message}");
                throw new Exception($"Không thể gửi mã OTP: {ex.Message}");
            }
        }

        public async Task<bool> VerifyOtpAsync(string phoneNumber, string code)
        {
            try
            {
                var check = await VerificationCheckResource.CreateAsync(
                    to: phoneNumber,
                    code: code,
                    pathServiceSid: _serviceSid
                );

                Console.WriteLine($"[Twilio] Verify check for {phoneNumber}: status={check.Status}");
                return check.Status == "approved";
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Twilio] Verify check failed for {phoneNumber}: {ex.Message}");
                return false;
            }
        }
    }
}
