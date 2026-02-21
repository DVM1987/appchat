using BuildingBlocks.Core;
using BuildingBlocks.CQRS;
using Identity.Application.Common.Interfaces;
using Identity.Domain.Entities;

namespace Identity.Application.Features.Auth
{
    public class VerifyOtpCommandHandler : ICommandHandler<VerifyOtpCommand, VerifyOtpResponse>
    {
        private readonly IOtpRepository _otpRepository;
        private readonly IUserRepository _userRepository;
        private readonly ITokenService _tokenService;
        private readonly IUnitOfWork _unitOfWork;
        private readonly IUserServiceClient _userServiceClient;

        public VerifyOtpCommandHandler(
            IOtpRepository otpRepository,
            IUserRepository userRepository,
            ITokenService tokenService,
            IUnitOfWork unitOfWork,
            IUserServiceClient userServiceClient)
        {
            _otpRepository = otpRepository;
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

            // 1. Verify OTP
            var otp = await _otpRepository.GetLatestAsync(phone);
            if (otp == null || !otp.IsValid(request.OtpCode))
            {
                throw new Exception("Invalid or expired OTP");
            }

            otp.MarkAsUsed();
            await _unitOfWork.SaveChangesAsync(cancellationToken);

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

            return new VerifyOtpResponse(token, 3600, isNewUser);
        }
    }
}
