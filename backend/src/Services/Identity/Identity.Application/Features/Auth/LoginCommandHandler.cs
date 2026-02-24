using BuildingBlocks.CQRS;
using Identity.Application.Common.Interfaces;
using Identity.Domain.Entities;
using BCrypt.Net;

namespace Identity.Application.Features.Auth
{
    public class LoginCommandHandler : ICommandHandler<LoginCommand, LoginResponse>
    {
        private readonly IUserRepository _userRepository;
        private readonly ITokenService _tokenService;

        public LoginCommandHandler(IUserRepository userRepository, ITokenService tokenService)
        {
            _userRepository = userRepository;
            _tokenService = tokenService;
        }

        public async Task<LoginResponse> Handle(LoginCommand request, CancellationToken cancellationToken)
        {
            // 1. Find user
            var normalizedEmail = request.Email.ToLowerInvariant();
            var user = await _userRepository.GetByEmailAsync(normalizedEmail);
            if (user == null)
            {
                throw new Exception("Invalid credentials");
            }

            // 2. Verify Password
            bool verified = BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash);
            if (!verified)
            {
                throw new Exception("Invalid credentials");
            }

            // 3. Generate Token
            var token = _tokenService.GenerateToken(user.Id, user.FullName, user.Email);

            // 4. Generate Refresh Token
            var refreshTokenValue = _tokenService.GenerateRefreshToken();
            var refreshToken = new RefreshToken(user.Id, refreshTokenValue);
            await _userRepository.SaveRefreshTokenAsync(refreshToken);

            // 5. Return
            return new LoginResponse(token, refreshTokenValue, 3600);
        }
    }
}
