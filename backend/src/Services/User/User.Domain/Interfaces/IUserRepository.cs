using User.Domain.Entities;

namespace User.Domain.Interfaces
{
    public interface IUserRepository
    {
        Task<UserProfile?> GetByIdentityIdAsync(Guid identityId);
        Task<UserProfile?> GetByIdAsync(Guid id);
        Task CreateAsync(UserProfile user);
        Task UpdateAsync(UserProfile user);
        Task<bool> ExistsAsync(Guid identityId);
        Task<List<UserProfile>> SearchAsync(string query);
        Task<UserProfile?> GetByEmailAsync(string email);
        Task<List<UserProfile>> GetByIdsAsync(List<Guid> ids);
        Task<List<UserProfile>> GetByIdentityIdsAsync(List<Guid> identityIds);
    }
}
