using Microsoft.AspNetCore.SignalR;

namespace User.API.Hubs
{
    public class UserHub : Hub
    {
        public override async Task OnConnectedAsync()
        {
            var userId = Context.UserIdentifier;
            Console.WriteLine($"[UserHub] OnConnectedAsync. UserIdentifier: {userId ?? "null"}");
            if (!string.IsNullOrEmpty(userId))
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, userId);
                Console.WriteLine($"[UserHub] User {userId} connected and added to group.");
            }
            await base.OnConnectedAsync();
        }

        public async Task JoinUserGroup(string userId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, userId);
        }
    }
}
