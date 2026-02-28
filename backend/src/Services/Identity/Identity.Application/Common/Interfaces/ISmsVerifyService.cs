namespace Identity.Application.Common.Interfaces
{
    public interface ISmsVerifyService
    {
        /// <summary>Sends OTP via eSMS to the given phone number.</summary>
        Task<bool> SendOtpAsync(string phoneNumber);

        /// <summary>Checks OTP entered by user. Returns true if valid.</summary>
        Task<bool> VerifyOtpAsync(string phoneNumber, string code);
    }
}
