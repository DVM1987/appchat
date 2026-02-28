using BuildingBlocks.Core;
using BuildingBlocks.CQRS;
using Identity.Application.Common.Interfaces;
using Identity.Domain.Entities;

namespace Identity.Application.Features.Auth
{
    public class VerifyFirebaseTokenCommandHandler : ICommandHandler<VerifyFirebaseTokenCommand, VerifyFirebaseTokenResponse>
    {
        private readonly IUserRepository _userRepository;
        private readonly ITokenService _tokenService;
        private readonly IUnitOfWork _unitOfWork;
        private readonly IUserServiceClient _userServiceClient;
        private readonly IFirebaseAuthService _firebaseAuthService;

        public VerifyFirebaseTokenCommandHandler(
            IUserRepository userRepository,
            ITokenService tokenService,
            IUnitOfWork unitOfWork,
            IUserServiceClient userServiceClient,
            IFirebaseAuthService firebaseAuthService)
        {
            _userRepository = userRepository;
            _tokenService = tokenService;
            _unitOfWork = unitOfWork;
            _userServiceClient = userServiceClient;
            _firebaseAuthService = firebaseAuthService;
        }

        public async Task<VerifyFirebaseTokenResponse> Handle(VerifyFirebaseTokenCommand request, CancellationToken cancellationToken)
        {
            // 1. Verify Firebase ID token and extract phone number
            var phone = await _firebaseAuthService.VerifyIdTokenAndGetPhoneAsync(request.IdToken);

            if (string.IsNullOrEmpty(phone))
            {
                throw new Exception("Firebase token does not contain a phone number");
            }

            Console.WriteLine($"[Firebase] Verified token for phone: {phone}");

            // 2. Find or create user
            var user = await _userRepository.GetByPhoneAsync(phone);
            bool isNewUser = user == null;

            if (isNewUser)
            {
                var fullName = request.FullName ?? phone; // Use phone as default name
                user = new User(phone, fullName, isPhoneAuth: true);
                await _userRepository.AddAsync(user);
                await _unitOfWork.SaveChangesAsync(cancellationToken);

                // Create profile in User Service
                try
                {
                    await _userServiceClient.CreateUserProfileAsync(user.Id, phone, fullName);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Warning: Failed to create user profile: {ex.Message}");
                }
            }

            // 3. For existing users, fetch latest name from User service
            var displayName = user!.FullName;
            if (!isNewUser)
            {
                try
                {
                    var latestName = await _userServiceClient.GetUserFullNameAsync(user.Id);
                    if (!string.IsNullOrEmpty(latestName))
                    {
                        displayName = latestName;
                    }
                }
                catch { /* Use Identity DB name as fallback */ }
            }

            // 4. Generate JWT token with latest name
            var token = _tokenService.GenerateToken(user.Id, displayName, user.Email ?? phone);

            // 5. Generate refresh token
            string refreshTokenValue = "";
            try
            {
                refreshTokenValue = _tokenService.GenerateRefreshToken();
                var refreshToken = new RefreshToken(user.Id, refreshTokenValue);
                await _userRepository.SaveRefreshTokenAsync(refreshToken);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Warning: Failed to save refresh token: {ex.Message}");
                refreshTokenValue = "";
            }

            return new VerifyFirebaseTokenResponse(token, refreshTokenValue, 3600, isNewUser);
        }
    }
}
