using BuildingBlocks.Core;

namespace Identity.Domain.Entities
{
    public class RefreshToken : Entity<Guid>
    {
        public Guid UserId { get; private set; }
        public string Token { get; private set; }
        public DateTime ExpiresAt { get; private set; }
        public DateTime CreatedAt { get; private set; }
        public bool IsRevoked { get; private set; }

        private RefreshToken() { }

        public RefreshToken(Guid userId, string token, int expiryDays = 30)
        {
            Id = Guid.NewGuid();
            UserId = userId;
            Token = token ?? throw new ArgumentNullException(nameof(token));
            ExpiresAt = DateTime.UtcNow.AddDays(expiryDays);
            CreatedAt = DateTime.UtcNow;
            IsRevoked = false;
        }

        public bool IsExpired => DateTime.UtcNow >= ExpiresAt;
        public bool IsActive => !IsRevoked && !IsExpired;

        public void Revoke()
        {
            IsRevoked = true;
        }
    }
}
