using Microsoft.EntityFrameworkCore;
using User.Domain.Entities;
using User.Domain.Interfaces;
using User.Infrastructure.Persistence;

namespace User.Infrastructure.Repositories
{
    public class FriendshipRepository : IFriendshipRepository
    {
        private readonly UserDbContext _context;

        public FriendshipRepository(UserDbContext context)
        {
            _context = context;
        }

        public async Task AddAsync(Friendship friendship)
        {
            await _context.Friendships.AddAsync(friendship);
        }

        public async Task<Friendship?> GetFriendshipAsync(Guid userId1, Guid userId2)
        {
            return await _context.Friendships
                .FirstOrDefaultAsync(f => 
                    (f.RequesterId == userId1 && f.AddresseeId == userId2) ||
                    (f.RequesterId == userId2 && f.AddresseeId == userId1));
        }

        public async Task<List<Friendship>> GetFriendshipsByUserIdAsync(Guid userId)
        {
            return await _context.Friendships
                .Where(f => (f.RequesterId == userId || f.AddresseeId == userId) && f.Status == FriendshipStatus.Accepted)
                .ToListAsync();
        }

        public async Task<List<Friendship>> GetPendingRequestsAsync(Guid userId)
        {
            return await _context.Friendships
                .Where(f => f.AddresseeId == userId && f.Status == FriendshipStatus.Pending)
                .ToListAsync();
        }

        public Task UpdateAsync(Friendship friendship)
        {
            _context.Friendships.Update(friendship);
            return Task.CompletedTask;
        }
    }
}
