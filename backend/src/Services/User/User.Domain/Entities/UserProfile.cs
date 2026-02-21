using BuildingBlocks.Core;

namespace User.Domain.Entities
{
    public enum UserStatus
    {
        Offline,
        Online,
        Busy,
        Away
    }

    public class UserProfile : AggregateRoot<Guid>
    {
        public Guid IdentityId { get; private set; }
        public string FullName { get; private set; }
        public string Email { get; private set; }
        public string? AvatarUrl { get; private set; }
        public string? Bio { get; private set; }
        public UserStatus Status { get; private set; }
        public DateTime LastActive { get; private set; }
        public string? DeviceToken { get; set; }     // FCM token for push notifications
        public string? DevicePlatform { get; set; }  // "android" or "ios"

        private UserProfile() { } // For EF Core

        public UserProfile(Guid identityId, string fullName, string email)
        {
            Id = Guid.NewGuid();
            IdentityId = identityId;
            FullName = fullName;
            Email = email;
            Status = UserStatus.Online;
            LastActive = DateTime.UtcNow;
        }

        public void UpdateProfile(string fullName, string? avatarUrl, string? bio)
        {
            FullName = fullName;
            AvatarUrl = avatarUrl;
            Bio = bio;
        }

        public void UpdateStatus(UserStatus status)
        {
            Status = status;
            LastActive = DateTime.UtcNow;
        }
    }
}
