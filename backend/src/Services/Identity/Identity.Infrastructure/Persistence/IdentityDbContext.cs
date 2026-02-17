using Identity.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Identity.Infrastructure.Persistence
{
    public class IdentityDbContext : DbContext
    {
        public DbSet<User> Users { get; set; }

        public IdentityDbContext(DbContextOptions<IdentityDbContext> options) : base(options)
        {
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
            
            modelBuilder.Entity<User>(ConfigureUser);
        }

        private void ConfigureUser(EntityTypeBuilder<User> builder)
        {
            builder.ToTable("Users");
            
            builder.HasKey(u => u.Id);
            
            builder.Property(u => u.Email)
                .IsRequired()
                .HasMaxLength(255);
            
            builder.HasIndex(u => u.Email)
                .IsUnique();

            builder.Property(u => u.FullName)
                .IsRequired()
                .HasMaxLength(100);

            builder.Property(u => u.PasswordHash)
                .IsRequired();

            builder.Property(u => u.AvatarUrl)
                .IsRequired(false);
        }
    }
}
