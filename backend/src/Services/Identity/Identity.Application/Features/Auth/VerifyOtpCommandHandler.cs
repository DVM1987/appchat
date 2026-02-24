using BuildingBlocks.Core;
using BuildingBlocks.CQRS;
using Identity.Application.Common.Interfaces;
using Identity.Domain.Entities;

namespace Identity.Application.Features.Auth
{
    public class VerifyOtpCommandHandler : ICommandHandler<VerifyOtpCommand, VerifyOtpResponse>
    {
        private readonly ISmsVerifyService _smsVerifyService;
        private readonly IUserRepository _userRepository;
        private readonly ITokenService _tokenService;
        private readonly IUnitOfWork _unitOfWork;
        private readonly IUserServiceClient _userServiceClient;

        public VerifyOtpCommandHandler(
            ISmsVerifyService smsVerifyService,
            IUserRepository userRepository,
            ITokenService tokenService,
            IUnitOfWork unitOfWork,
            IUserServiceClient userServiceClient)
        {
            _smsVerifyService = smsVerifyService;
            _userRepository = userRepository;
            _tokenService = tokenService;
            _unitOfWork = unitOfWork;
            _userServiceClient = userServiceClient;
        }

        public async Task<VerifyOtpResponse> Handle(VerifyOtpCommand request, CancellationToken cancellationToken)
        {
            // Normalize phone
            var phone = request.PhoneNumber.Trim();
            if (!phone.StartsWith("+"))
                phone = "+84" + phone.TrimStart('0');

            // 1. Verify OTP via Twilio Verify
            var isValid = await _smsVerifyService.VerifyOtpAsync(phone, request.OtpCode);
            if (!isValid)
            {
                throw new Exception("Invalid or expired OTP");
            }

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

            // 3. Generate JWT token
            var token = _tokenService.GenerateToken(user!.Id, user.FullName, user.Email ?? phone);

            // 4. Generate refresh token
            var refreshTokenValue = _tokenService.GenerateRefreshToken();
            var refreshToken = new RefreshToken(user.Id, refreshTokenValue);
            await _userRepository.SaveRefreshTokenAsync(refreshToken);

            return new VerifyOtpResponse(token, refreshTokenValue, 3600, isNewUser);
        }
    }
}
