using Chat.Domain.Entities;
using Microsoft.Extensions.Configuration;
using MongoDB.Driver;

namespace Chat.Infrastructure.Persistence
{
    public class ChatContext
    {
        private readonly IMongoDatabase _database;

        public ChatContext(IConfiguration configuration)
        {
            var connectionString = configuration.GetValue<string>("DatabaseSettings:ConnectionString");
            var databaseName = configuration.GetValue<string>("DatabaseSettings:DatabaseName");
            var client = new MongoClient(connectionString);
            _database = client.GetDatabase(databaseName);
        }

        public IMongoCollection<Conversation> Conversations => _database.GetCollection<Conversation>("conversations");
        public IMongoCollection<Message> Messages => _database.GetCollection<Message>("messages");
    }
}
