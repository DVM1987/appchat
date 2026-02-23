namespace Identity.Application.Common.Interfaces
{
    public interface ISmsVerifyService
    {
        /// <summary>Sends OTP via Twilio Verify to the given phone number.</summary>
        Task<bool> SendOtpAsync(string phoneNumber);

        /// <summary>Checks OTP entered by user against Twilio Verify. Returns true if valid.</summary>
        Task<bool> VerifyOtpAsync(string phoneNumber, string code);
    }
}
