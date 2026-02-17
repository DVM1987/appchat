using User.Domain.Entities;

namespace User.Domain.Interfaces
{
    public interface IFriendshipRepository
    {
        Task<Friendship?> GetFriendshipAsync(Guid userId1, Guid userId2);
        Task<List<Friendship>> GetFriendshipsByUserIdAsync(Guid userId);
        Task<List<Friendship>> GetPendingRequestsAsync(Guid userId);
        Task AddAsync(Friendship friendship);
        Task UpdateAsync(Friendship friendship);
    }
}
