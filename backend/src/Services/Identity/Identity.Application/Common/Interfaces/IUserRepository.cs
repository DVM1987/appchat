using Identity.Domain.Entities;

namespace Identity.Application.Common.Interfaces
{
    public interface IUserRepository
    {
        Task<bool> IsEmailUniqueAsync(string email);
        Task AddAsync(User user);
        Task<User?> GetByEmailAsync(string email);
        Task<User?> GetByPhoneAsync(string phoneNumber);
        Task<bool> IsPhoneUniqueAsync(string phoneNumber);
        Task<User?> GetByIdAsync(Guid userId);

        // Refresh Token
        Task SaveRefreshTokenAsync(RefreshToken refreshToken);
        Task<RefreshToken?> GetRefreshTokenAsync(string token);
        Task RevokeRefreshTokenAsync(string token);
    }
}
