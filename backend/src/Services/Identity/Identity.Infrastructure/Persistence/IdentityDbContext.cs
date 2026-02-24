using Identity.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Identity.Infrastructure.Persistence
{
    public class IdentityDbContext : DbContext
    {
        public DbSet<User> Users { get; set; }
        public DbSet<OtpEntry> OtpEntries { get; set; }
        public DbSet<RefreshToken> RefreshTokens { get; set; }

        public IdentityDbContext(DbContextOptions<IdentityDbContext> options) : base(options)
        {
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
            
            modelBuilder.Entity<User>(ConfigureUser);
            modelBuilder.Entity<OtpEntry>(ConfigureOtpEntry);
            modelBuilder.Entity<RefreshToken>(ConfigureRefreshToken);
        }

        private void ConfigureUser(EntityTypeBuilder<User> builder)
        {
            builder.ToTable("Users");
            
            builder.HasKey(u => u.Id);
            
            builder.Property(u => u.Email)
                .IsRequired(false)
                .HasMaxLength(255);
            
            builder.HasIndex(u => u.Email)
                .IsUnique()
                .HasFilter("\"Email\" IS NOT NULL");

            builder.Property(u => u.PhoneNumber)
                .IsRequired(false)
                .HasMaxLength(20);

            builder.HasIndex(u => u.PhoneNumber)
                .IsUnique()
                .HasFilter("\"PhoneNumber\" IS NOT NULL");

            builder.Property(u => u.FullName)
                .IsRequired()
                .HasMaxLength(100);

            builder.Property(u => u.PasswordHash)
                .IsRequired(false);

            builder.Property(u => u.AvatarUrl)
                .IsRequired(false);
        }

        private void ConfigureOtpEntry(EntityTypeBuilder<OtpEntry> builder)
        {
            builder.ToTable("OtpEntries");

            builder.HasKey(o => o.Id);

            builder.Property(o => o.PhoneNumber)
                .IsRequired()
                .HasMaxLength(20);

            builder.HasIndex(o => o.PhoneNumber);

            builder.Property(o => o.Code)
                .IsRequired()
                .HasMaxLength(10);
        }

        private void ConfigureRefreshToken(EntityTypeBuilder<RefreshToken> builder)
        {
            builder.ToTable("RefreshTokens");

            builder.HasKey(r => r.Id);

            builder.Property(r => r.Token)
                .IsRequired()
                .HasMaxLength(256);

            builder.HasIndex(r => r.Token)
                .IsUnique();

            builder.HasIndex(r => r.UserId);
        }
    }
}
