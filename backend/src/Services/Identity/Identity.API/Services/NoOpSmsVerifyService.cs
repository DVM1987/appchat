using Identity.Application.Common.Interfaces;

namespace Identity.API.Services
{
    /// <summary>
    /// No-op SMS verify service — used as a placeholder since Firebase handles OTP now.
    /// The old /send-otp and /verify-otp endpoints still work for the Apple test account
    /// bypass (hardcoded in SendOtpCommandHandler and VerifyOtpCommandHandler).
    /// </summary>
    public class NoOpSmsVerifyService : ISmsVerifyService
    {
        public Task<bool> SendOtpAsync(string phoneNumber)
        {
            Console.WriteLine($"[NoOp] SendOtp called for {phoneNumber} — SMS providers removed, use Firebase Phone Auth");
            throw new Exception("SMS OTP đã được thay thế bằng Firebase Phone Auth. Vui lòng cập nhật ứng dụng.");
        }

        public Task<bool> VerifyOtpAsync(string phoneNumber, string code)
        {
            Console.WriteLine($"[NoOp] VerifyOtp called for {phoneNumber} — SMS providers removed");
            return Task.FromResult(false);
        }
    }
}
