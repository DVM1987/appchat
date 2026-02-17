using Microsoft.EntityFrameworkCore;
using User.Domain.Entities;

namespace User.Infrastructure.Persistence
{
    public class UserDbContext : DbContext
    {
        public DbSet<UserProfile> UserProfiles { get; set; }
        public DbSet<Friendship> Friendships { get; set; }

        public UserDbContext(DbContextOptions<UserDbContext> options) : base(options)
        {
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.ApplyConfigurationsFromAssembly(typeof(UserDbContext).Assembly);

            modelBuilder.Entity<UserProfile>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.IdentityId).IsRequired();
                entity.HasIndex(e => e.IdentityId).IsUnique(); // One profile per identity
                entity.Property(e => e.FullName).IsRequired().HasMaxLength(100);
                entity.Property(e => e.Email).IsRequired().HasMaxLength(100);
            });

            modelBuilder.Entity<Friendship>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.HasIndex(e => new { e.RequesterId, e.AddresseeId }).IsUnique();
            });

            base.OnModelCreating(modelBuilder);
        }
    }
}
