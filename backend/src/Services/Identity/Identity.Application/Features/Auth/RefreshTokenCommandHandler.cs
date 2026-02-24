using BuildingBlocks.CQRS;
using Identity.Application.Common.Interfaces;
using Identity.Domain.Entities;

namespace Identity.Application.Features.Auth
{
    public class RefreshTokenCommandHandler : ICommandHandler<RefreshTokenCommand, RefreshTokenResponse>
    {
        private readonly ITokenService _tokenService;
        private readonly IUserRepository _userRepository;

        public RefreshTokenCommandHandler(ITokenService tokenService, IUserRepository userRepository)
        {
            _tokenService = tokenService;
            _userRepository = userRepository;
        }

        public async Task<RefreshTokenResponse> Handle(RefreshTokenCommand request, CancellationToken cancellationToken)
        {
            // 1. Validate the expired access token (ignore expiry)
            var principal = _tokenService.GetPrincipalFromExpiredToken(request.AccessToken);
            if (principal == null)
            {
                throw new Exception("Invalid access token");
            }

            // 2. Extract userId from the expired token
            var userIdClaim = principal.FindFirst("sub")?.Value
                           ?? principal.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
            {
                throw new Exception("Invalid access token - no user ID");
            }

            // 3. Validate the refresh token
            var storedToken = await _userRepository.GetRefreshTokenAsync(request.RefreshToken);
            if (storedToken == null || storedToken.UserId != userId || !storedToken.IsActive)
            {
                throw new Exception("Invalid or expired refresh token");
            }

            // 4. Get user
            var user = await _userRepository.GetByIdAsync(userId);
            if (user == null)
            {
                throw new Exception("User not found");
            }

            // 5. Revoke old refresh token
            await _userRepository.RevokeRefreshTokenAsync(request.RefreshToken);

            // 6. Generate new token pair
            var newAccessToken = _tokenService.GenerateToken(user.Id, user.FullName, user.Email ?? user.PhoneNumber ?? "");
            var newRefreshToken = _tokenService.GenerateRefreshToken();

            // 7. Save new refresh token
            var refreshTokenEntity = new RefreshToken(user.Id, newRefreshToken);
            await _userRepository.SaveRefreshTokenAsync(refreshTokenEntity);

            return new RefreshTokenResponse(newAccessToken, newRefreshToken, 3600);
        }
    }
}
