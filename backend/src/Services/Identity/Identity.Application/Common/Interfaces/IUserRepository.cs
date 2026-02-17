using Identity.Domain.Entities;

namespace Identity.Application.Common.Interfaces
{
    public interface IUserRepository
    {
        Task<bool> IsEmailUniqueAsync(string email);
        Task AddAsync(User user);
        Task<User?> GetByEmailAsync(string email);
    }
}
