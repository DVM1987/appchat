using BuildingBlocks.Core;
using System;
using System.Collections.Generic;

namespace Identity.Domain.Entities
{
    public class User : AggregateRoot<Guid>
    {
        public string Email { get; private set; }
        public string PasswordHash { get; private set; }
        public string FullName { get; private set; }
        public string? AvatarUrl { get; private set; }
        public DateTime CreatedAt { get; private set; }
        public DateTime? LastActive { get; private set; }

        // Private constructor for EF Core
        private User() { }

        public User(string email, string passwordHash, string fullName)
        {
            Id = Guid.NewGuid();
            Email = email ?? throw new ArgumentNullException(nameof(email));
            PasswordHash = passwordHash ?? throw new ArgumentNullException(nameof(passwordHash));
            FullName = fullName ?? throw new ArgumentNullException(nameof(fullName));
            CreatedAt = DateTime.UtcNow;
            LastActive = DateTime.UtcNow;
            
            // Add Domain Event (e.g. UserRegistered)
        }

        public void UpdateProfile(string fullName, string avatarUrl)
        {
            FullName = fullName;
            AvatarUrl = avatarUrl;
        }

        public void UpdateLastActive()
        {
            LastActive = DateTime.UtcNow;
        }
    }
}
