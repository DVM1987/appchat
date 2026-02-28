using FirebaseAdmin.Auth;
using Identity.Application.Common.Interfaces;

namespace Identity.API.Services
{
    /// <summary>
    /// Verifies Firebase ID tokens using the Firebase Admin SDK.
    /// </summary>
    public class FirebaseAuthService : IFirebaseAuthService
    {
        public async Task<string> VerifyIdTokenAndGetPhoneAsync(string idToken)
        {
            try
            {
                // Verify the ID token with Firebase Admin SDK
                var decodedToken = await FirebaseAuth.DefaultInstance.VerifyIdTokenAsync(idToken);

                // Extract phone number from claims
                var phoneNumber = decodedToken.Claims.TryGetValue("phone_number", out var phone)
                    ? phone?.ToString()
                    : null;

                if (string.IsNullOrEmpty(phoneNumber))
                {
                    throw new Exception("Firebase token does not contain a phone number");
                }

                Console.WriteLine($"[Firebase] Token verified — UID={decodedToken.Uid}, phone={phoneNumber}");
                return phoneNumber;
            }
            catch (FirebaseAuthException ex)
            {
                Console.WriteLine($"[Firebase] Token verification failed: {ex.Message}");
                throw new Exception($"Invalid Firebase token: {ex.Message}");
            }
        }
    }
}
