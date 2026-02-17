using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using User.Domain.Interfaces;
using User.Infrastructure.Persistence;
using User.Infrastructure.Repositories;
using User.Infrastructure.Services;

namespace User.Infrastructure
{
    public static class UserServiceRegistration
    {
        public static IServiceCollection AddUserInfrastructure(this IServiceCollection services, IConfiguration configuration)
        {
            services.AddDbContext<UserDbContext>(options =>
                options.UseNpgsql(configuration.GetConnectionString("DefaultConnection")));

            services.AddScoped<IUserRepository, UserRepository>();
            services.AddScoped<IFriendshipRepository, FriendshipRepository>();
            services.AddScoped<IUnitOfWork, UnitOfWork>();

            // MassTransit Config usually goes here or in Application layer depending on preference
            // For now we keep it simple in API Program.cs or separate method

            return services;
        }
    }
}
