using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Chat.Domain.Interfaces;
using Chat.Infrastructure.Repositories;
using Chat.Infrastructure.Persistence;
using MongoDB.Bson.Serialization.Serializers;
using MongoDB.Bson.Serialization;
using MongoDB.Bson;

namespace Chat.Infrastructure
{
    public static class ChatServiceRegistration
    {
        public static IServiceCollection AddChatInfrastructure(this IServiceCollection services, IConfiguration configuration)
        {
            // Register Serializers
            BsonSerializer.TryRegisterSerializer(new GuidSerializer(GuidRepresentation.Standard));

            services.AddSingleton<ChatContext>();
            services.AddScoped<IChatRepository, ChatRepository>();

            return services;
        }
    }
}
