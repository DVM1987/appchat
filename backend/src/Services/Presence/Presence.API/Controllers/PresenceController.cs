using Microsoft.AspNetCore.Mvc;
using Presence.Infrastructure.Services;

namespace Presence.API.Controllers
{
    [ApiController]
    [Route("api/v1/[controller]")]
    public class PresenceController : ControllerBase
    {
        private readonly IPresenceService _presenceService;

        public PresenceController(IPresenceService presenceService)
        {
            _presenceService = presenceService;
        }

        [HttpGet("{userId}")]
        public async Task<IActionResult> GetUserPresence(string userId)
        {
            var presence = await _presenceService.GetUserPresenceAsync(userId);
            if (presence == null)
            {
                return Ok(new
                {
                    UserId = userId,
                    Status = "Offline",
                    LastSeen = DateTime.MinValue
                });
            }

            return Ok(new 
            {
                presence.UserId,
                Status = presence.Status.ToString(),
                presence.LastSeen
            });
        }

        [HttpPost("batch")]
        public async Task<IActionResult> GetUsersPresence([FromBody] List<string> userIds)
        {
            var presences = await _presenceService.GetUsersPresenceAsync(userIds);
            return Ok(presences);
        }
    }
}
