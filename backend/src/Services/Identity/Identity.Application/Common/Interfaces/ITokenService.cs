using System.Security.Claims;

namespace Identity.Application.Common.Interfaces
{
    public interface ITokenService
    {
        string GenerateToken(Guid userId, string fullName, string email);
        string GenerateRefreshToken();
        ClaimsPrincipal? GetPrincipalFromExpiredToken(string token);
    }
}
