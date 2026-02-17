using Microsoft.EntityFrameworkCore;
using User.Domain.Entities;
using User.Domain.Interfaces;
using User.Infrastructure.Persistence;

namespace User.Infrastructure.Repositories
{
    public class UserRepository : IUserRepository
    {
        private readonly UserDbContext _context;

        public UserRepository(UserDbContext context)
        {
            _context = context;
        }

        public async Task CreateAsync(UserProfile user)
        {
            await _context.UserProfiles.AddAsync(user);
        }

        public async Task<bool> ExistsAsync(Guid identityId)
        {
            return await _context.UserProfiles.AnyAsync(u => u.IdentityId == identityId);
        }

        public async Task<UserProfile?> GetByIdAsync(Guid id)
        {
            return await _context.UserProfiles.FindAsync(id);
        }

        public async Task<UserProfile?> GetByIdentityIdAsync(Guid identityId)
        {
            return await _context.UserProfiles.FirstOrDefaultAsync(u => u.IdentityId == identityId);
        }

        public async Task<List<UserProfile>> SearchAsync(string query)
        {
            if (string.IsNullOrWhiteSpace(query)) return new List<UserProfile>();
            
            query = query.ToLower();
            return await _context.UserProfiles
                .Where(u => u.FullName.ToLower().Contains(query) || u.Email.ToLower().Contains(query))
                .Take(20)
                .ToListAsync();
        }

        public async Task<UserProfile?> GetByEmailAsync(string email)
        {
            return await _context.UserProfiles.FirstOrDefaultAsync(u => u.Email == email);
        }

        public async Task UpdateAsync(UserProfile user)
        {
            _context.UserProfiles.Update(user);
            await _context.SaveChangesAsync();
        }

        public async Task<List<UserProfile>> GetByIdsAsync(List<Guid> ids)
        {
            return await _context.UserProfiles
                .Where(u => ids.Contains(u.Id))
                .ToListAsync();
        }
    }
}
