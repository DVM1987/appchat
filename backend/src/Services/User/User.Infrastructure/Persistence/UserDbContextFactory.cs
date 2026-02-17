using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace User.Infrastructure.Persistence
{
    public class UserDbContextFactory : IDesignTimeDbContextFactory<UserDbContext>
    {
        public UserDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<UserDbContext>();

            // Read from appsettings or environment variable for migrations
            var configuration = new ConfigurationBuilder()
                .SetBasePath(Path.Combine(Directory.GetCurrentDirectory(), "..", "User.API"))
                .AddJsonFile("appsettings.json", optional: true)
                .AddJsonFile("appsettings.Development.json", optional: true)
                .AddEnvironmentVariables()
                .Build();

            var connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? Environment.GetEnvironmentVariable("USER_DB_CONNECTION")
                ?? throw new InvalidOperationException("Database connection string not configured.");

            optionsBuilder.UseNpgsql(connectionString);

            return new UserDbContext(optionsBuilder.Options);
        }
    }
}
