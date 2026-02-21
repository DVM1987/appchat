using BuildingBlocks.Core;

namespace Identity.Domain.Entities
{
    public class OtpEntry : Entity<Guid>
    {
        public string PhoneNumber { get; private set; }
        public string Code { get; private set; }
        public DateTime ExpiresAt { get; private set; }
        public bool IsUsed { get; private set; }
        public DateTime CreatedAt { get; private set; }

        private OtpEntry() { }

        public OtpEntry(string phoneNumber, string code, int ttlSeconds = 300)
        {
            Id = Guid.NewGuid();
            PhoneNumber = phoneNumber ?? throw new ArgumentNullException(nameof(phoneNumber));
            Code = code ?? throw new ArgumentNullException(nameof(code));
            ExpiresAt = DateTime.UtcNow.AddSeconds(ttlSeconds);
            IsUsed = false;
            CreatedAt = DateTime.UtcNow;
        }

        public bool IsValid(string code)
        {
            return !IsUsed && DateTime.UtcNow < ExpiresAt && Code == code;
        }

        public void MarkAsUsed()
        {
            IsUsed = true;
        }
    }
}
