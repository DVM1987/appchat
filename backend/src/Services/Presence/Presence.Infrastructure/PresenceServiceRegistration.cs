using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Presence.Infrastructure.Services;
using StackExchange.Redis;

namespace Presence.Infrastructure
{
    public static class PresenceServiceRegistration
    {
        public static IServiceCollection AddPresenceInfrastructure(this IServiceCollection services, IConfiguration configuration)
        {
            // Redis
            var redisConnection = configuration.GetConnectionString("Redis") ?? "localhost:6379";
            services.AddSingleton<IConnectionMultiplexer>(ConnectionMultiplexer.Connect(redisConnection));
            
            // Services
            services.AddScoped<IPresenceService, PresenceService>();

            return services;
        }
    }
}
