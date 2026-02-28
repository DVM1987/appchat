namespace Identity.Application.Common.Interfaces
{
    /// <summary>
    /// Service for verifying Firebase Authentication tokens.
    /// </summary>
    public interface IFirebaseAuthService
    {
        /// <summary>
        /// Verifies a Firebase ID token and extracts the phone number.
        /// Returns the phone number in E.164 format (e.g., +84961998923).
        /// Throws if the token is invalid.
        /// </summary>
        Task<string> VerifyIdTokenAndGetPhoneAsync(string idToken);
    }
}
