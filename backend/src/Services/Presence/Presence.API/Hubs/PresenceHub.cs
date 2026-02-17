using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Presence.Infrastructure.Services;

namespace Presence.API.Hubs
{
    [Authorize]
    public class PresenceHub : Hub
    {
        private readonly IPresenceService _presenceService;

        public PresenceHub(IPresenceService presenceService)
        {
            _presenceService = presenceService;
        }

        public async Task Heartbeat()
        {
            var userId = Context.User?.FindFirst("sub")?.Value ?? Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!string.IsNullOrEmpty(userId))
            {
                await _presenceService.SetUserOnlineAsync(userId, Context.ConnectionId);
            }
        }

        public override async Task OnConnectedAsync()
        {
            var userId = Context.User?.FindFirst("sub")?.Value ?? Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            
            Console.WriteLine($"[PresenceHub] OnConnected: ConnectionId={Context.ConnectionId}, IsAuth={Context.User?.Identity?.IsAuthenticated}");
            if (Context.User != null)
            {
                foreach (var claim in Context.User.Claims)
                {
                    Console.WriteLine($" - Claim: {claim.Type} = {claim.Value}");
                }
            }
            
            if (!string.IsNullOrEmpty(userId))
            {
                await _presenceService.SetUserOnlineAsync(userId, Context.ConnectionId);
                await Clients.Others.SendAsync("UserOnline", userId);
            }
            else 
            {
                 Console.WriteLine("[PresenceHub] WARNING: Connected but UserId (sub/NameIdentifier) is missing!");
            }

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = Context.User?.FindFirst("sub")?.Value ?? Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            
            if (!string.IsNullOrEmpty(userId))
            {
                var isTrulyOffline = await _presenceService.SetUserOfflineAsync(userId, Context.ConnectionId);
                // Only broadcast Offline event if user has no more active connections
                if (isTrulyOffline)
                {
                    await Clients.Others.SendAsync("UserOffline", userId);
                }
            }

            await base.OnDisconnectedAsync(exception);
        }
        public async Task<object?> GetPresence(string userId)
        {
            var presence = await _presenceService.GetUserPresenceAsync(userId);
            if (presence == null) return null;
            
            return new 
            {
                UserId = presence.UserId,
                Status = presence.Status.ToString(),
                LastSeen = presence.LastSeen
            };
        }
        public async Task<List<object>> GetPresences(List<string> userIds)
        {
            var presences = await _presenceService.GetUsersPresenceAsync(userIds);
            
            return presences.Select(p => new 
            {
                UserId = p.UserId,
                Status = p.Status.ToString(),
                LastSeen = p.LastSeen
            }).Cast<object>().ToList();
        }
    }
}
