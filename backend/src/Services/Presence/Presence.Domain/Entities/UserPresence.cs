namespace Presence.Domain.Entities
{
    public class UserPresence
    {
        public string UserId { get; set; }
        public UserStatus Status { get; set; }
        public DateTime LastSeen { get; set; }
        public string? ConnectionId { get; set; }

        public UserPresence(string userId, UserStatus status, string? connectionId = null)
        {
            UserId = userId;
            Status = status;
            LastSeen = DateTime.UtcNow;
            ConnectionId = connectionId;
        }

        public void UpdateStatus(UserStatus newStatus)
        {
            Status = newStatus;
            LastSeen = DateTime.UtcNow;
        }
    }

    public enum UserStatus
    {
        Offline = 0,
        Online = 1,
        Away = 2,
        Busy = 3
    }
}
