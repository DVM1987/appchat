using BuildingBlocks.Core;

namespace User.Domain.Entities
{
    public enum FriendshipStatus
    {
        Pending,
        Accepted,
        Declined,
        Blocked
    }

    public class Friendship : Entity<int>
    {
        public Guid RequesterId { get; private set; }
        public Guid AddresseeId { get; private set; }
        public FriendshipStatus Status { get; private set; }
        public DateTime CreatedAt { get; private set; }

        private Friendship() { } 

        public Friendship(Guid requesterId, Guid addresseeId)
        {
            RequesterId = requesterId;
            AddresseeId = addresseeId;
            Status = FriendshipStatus.Pending;
            CreatedAt = DateTime.UtcNow;
        }

        public void Accept()
        {
            Status = FriendshipStatus.Accepted;
        }

        public void Decline()
        {
            Status = FriendshipStatus.Declined;
        }

        public void Block()
        {
            Status = FriendshipStatus.Blocked;
        }

        public void Reset(Guid requesterId, Guid addresseeId)
        {
            RequesterId = requesterId;
            AddresseeId = addresseeId;
            Status = FriendshipStatus.Pending;
            CreatedAt = DateTime.UtcNow;
        }
    }
}
