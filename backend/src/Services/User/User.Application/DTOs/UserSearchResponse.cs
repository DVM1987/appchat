using User.Domain.Entities;

namespace User.Application.DTOs
{
    public class UserSearchResponse
    {
        public Guid Id { get; set; }
        public Guid IdentityId { get; set; }
        public string FullName { get; set; }
        public string Email { get; set; }
        public string? AvatarUrl { get; set; }
        public string? Bio { get; set; }
        public int Status { get; set; }
        public DateTime? LastActive { get; set; }
        
        // Friendship status relative to requester
        // "None", "Pending_Sent", "Pending_Received", "Accepted", "Blocked"
        public string FriendshipStatus { get; set; } = "None";
    }
}
