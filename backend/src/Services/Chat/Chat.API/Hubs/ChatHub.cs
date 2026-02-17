using Microsoft.AspNetCore.SignalR;
using Chat.Domain.Interfaces;
using System.Collections.Concurrent;

namespace Chat.API.Hubs
{
    public class ChatHub : Hub
    {
        // Mapping between UserId and ConnectionIds
        // In Scaled out scenario (Redis Backplane), this needs external store or Group management
        // For now, we rely on built-in Groups which is fine.
        
        private readonly IChatRepository _repository;

        // Constructor Injection
        public ChatHub(IChatRepository repository)
        {
            _repository = repository;
        }

        public override async Task OnConnectedAsync()
        {
            // Use Context.UserIdentifier which is populated by JwtBearer Auth (sub claim)
            var userId = Context.UserIdentifier;
            
            if (!string.IsNullOrEmpty(userId))
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, userId);
                Console.WriteLine($"User {userId} connected and added to personal group.");
            }
            else
            {
                Console.WriteLine("User connected without Valid Token/UserId.");
            }
            
            await base.OnConnectedAsync();
        }

        public async Task JoinConversation(string conversationId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, conversationId);
            Console.WriteLine($"[ChatHub] Connection {Context.ConnectionId} joined group {conversationId}");
        }

        public async Task LeaveConversation(string conversationId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, conversationId);
        }

        public async Task Typing(string conversationId, string userId)
        {
            // Extract Name from Claims
            var userName = Context.User?.Claims.FirstOrDefault(c => c.Type == "name" || c.Type == System.Security.Claims.ClaimTypes.Name)?.Value ?? "Someone";
            
            await Clients.Group(conversationId).SendAsync("UserTyping", conversationId, userId, userName);
        }

        public async Task MarkAsRead(string conversationId)
        {
            var userId = Context.UserIdentifier;
            Console.WriteLine($"[ChatHub] MarkAsRead called by {userId} for {conversationId}");
            if (string.IsNullOrEmpty(userId)) return;

            await _repository.MarkMessagesAsReadAsync(conversationId, userId);
            
            // Broadcast to participants (replaces previous Group broadcast to avoid double delivery)
            var conversation = await _repository.GetConversationAsync(conversationId);
            if (conversation != null && conversation.ParticipantIds.Any())
            {
               await Clients.Users(conversation.ParticipantIds).SendAsync("MessagesRead", conversationId, userId);
            }
            
            Console.WriteLine($"[ChatHub] Broadcasted MessagesRead to participants for {conversationId}");
        }
    }
}
