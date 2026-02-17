using Presence.Domain.Entities;
using StackExchange.Redis;
using System.Text.Json;

namespace Presence.Infrastructure.Services
{
    public interface IPresenceService
    {
        Task SetUserOnlineAsync(string userId, string connectionId);
        Task<bool> SetUserOfflineAsync(string userId, string connectionId);
        Task<UserPresence?> GetUserPresenceAsync(string userId);
        Task<List<UserPresence>> GetUsersPresenceAsync(List<string> userIds);
    }

    public class PresenceService : IPresenceService
    {
        private readonly IDatabase _redis;
        private const string PresenceKeyPrefix = "presence:";
        private const int OnlineExpirySeconds = 60; // 1 minute heartbeat (faster offline detection)
        private const int OfflineExpirySeconds = 86400 * 7; // 7 days history

        public PresenceService(IConnectionMultiplexer redis)
        {
            _redis = redis.GetDatabase();
        }

        public async Task SetUserOnlineAsync(string userId, string connectionId)
        {
            var presenceKey = GetPresenceKey(userId);
            var connectionsKey = GetConnectionsKey(userId);

            // Add connectionId to the set of active connections
            await _redis.SetAddAsync(connectionsKey, connectionId);
            
            // Refresh presence data
            var presence = new UserPresence(userId, UserStatus.Online, connectionId); 
            // Note: Storing just 'last' connectionId in presence object for display/reference, 
            // but logic relies on the Set.
            
            var value = JsonSerializer.Serialize(presence);
            
            Console.WriteLine($"[PresenceService] SetUserOnline: Key={presenceKey}, Conn={connectionId}");
            
            // Update presence info to Online
            await _redis.StringSetAsync(presenceKey, value, TimeSpan.FromSeconds(OnlineExpirySeconds));
            // Extend Set expiry too
            await _redis.KeyExpireAsync(connectionsKey, TimeSpan.FromSeconds(OnlineExpirySeconds));
        }

        public async Task<bool> SetUserOfflineAsync(string userId, string connectionId)
        {
            var presenceKey = GetPresenceKey(userId);
            var connectionsKey = GetConnectionsKey(userId);

            // Remove this specific connection
            await _redis.SetRemoveAsync(connectionsKey, connectionId);
            
            // Check if any connections remain
            var remainingConnections = await _redis.SetLengthAsync(connectionsKey);

            Console.WriteLine($"[PresenceService] SetUserOffline: Key={presenceKey}, RemovingConn={connectionId}, Remaining={remainingConnections}");

            if (remainingConnections <= 0)
            {
                // No active connections left -> Mark as Offline
                var value = await _redis.StringGetAsync(presenceKey);
                if (!value.IsNullOrEmpty)
                {
                    var presence = JsonSerializer.Deserialize<UserPresence>(value!)!;
                    presence.UpdateStatus(UserStatus.Offline);
                    
                    var newValue = JsonSerializer.Serialize(presence);
                    
                    // Persist for history/last seen
                    await _redis.StringSetAsync(presenceKey, newValue, TimeSpan.FromSeconds(OfflineExpirySeconds));
                }
                
                // Clean up the empty set key immediately or let it expire
                await _redis.KeyDeleteAsync(connectionsKey);
                return true; // Truly offline
            }
            else 
            {
                // Still online on other devices/tabs
                // Just refresh the expiry of the presence key to keep it alive
                await _redis.KeyExpireAsync(presenceKey, TimeSpan.FromSeconds(OnlineExpirySeconds));
                await _redis.KeyExpireAsync(connectionsKey, TimeSpan.FromSeconds(OnlineExpirySeconds));
                return false; // Still online
            }
        }

        public async Task<UserPresence?> GetUserPresenceAsync(string userId)
        {
            var key = GetPresenceKey(userId);
            var value = await _redis.StringGetAsync(key);
            
            Console.WriteLine($"[PresenceService] GetUserPresence: Key={key}, Found={!value.IsNullOrEmpty}");
            
            if (value.IsNullOrEmpty)
                return null;

            try 
            {
                return JsonSerializer.Deserialize<UserPresence>(value!);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[PresenceService] Deserialization Error: {ex.Message}");
                return null;
            }
        }

        public async Task<List<UserPresence>> GetUsersPresenceAsync(List<string> userIds)
        {
            var tasks = userIds.Select(GetUserPresenceAsync);
            var results = await Task.WhenAll(tasks);
            
            return results.Where(p => p != null).ToList()!;
        }

        private string GetPresenceKey(string userId) => $"{PresenceKeyPrefix}{userId}";
        private string GetConnectionsKey(string userId) => $"{PresenceKeyPrefix}connections:{userId}";
    }
}
