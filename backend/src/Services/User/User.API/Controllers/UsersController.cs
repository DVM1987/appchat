using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using User.Application.Features.Profiles;

namespace User.API.Controllers
{
    [ApiController]
    [Route("api/v1/[controller]")]
    public class UsersController : ControllerBase
    {
        private readonly IMediator _mediator;
        private readonly User.Domain.Interfaces.IUserRepository _userRepository;

        public UsersController(IMediator mediator, User.Domain.Interfaces.IUserRepository userRepository)
        {
            _mediator = mediator;
            _userRepository = userRepository;
        }

        [HttpGet("identity/{identityId}")]
        public async Task<IActionResult> GetProfileByIdentity(Guid identityId)
        {
            var result = await _mediator.Send(new GetUserProfileByIdentityQuery(identityId));
            if (result == null) return NotFound();
            return Ok(result);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetProfile(Guid id)
        {
            var result = await _mediator.Send(new GetUserProfileQuery(id));
            if (result == null) return NotFound();
            return Ok(result);
        }

        // Internal endpoint for creating profile, or listening to MassTransit
        // But for testing flexibility, we can expose it
        [HttpPost]
        public async Task<IActionResult> CreateProfile([FromBody] CreateUserProfileCommand command)
        {
            var id = await _mediator.Send(command);
            return CreatedAtAction(nameof(GetProfile), new { id = command.IdentityId }, new { id });
        }

        [HttpGet("email/{email}")]
        [Authorize]
        public async Task<IActionResult> GetProfileByEmail(string email)
        {
            // Extract requesterId from token
            Guid? requesterId = null;
            var userIdClaim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
            
            if (userIdClaim != null)
            {
                if (Guid.TryParse(userIdClaim.Value, out var identityId))
                {
                    var profile = await _userRepository.GetByIdentityIdAsync(identityId);
                    requesterId = profile?.Id;
                }
                else 
                {
                    Console.WriteLine($"[UsersController] Failed to parse IdentityId from claim: {userIdClaim.Value}");
                }
            }
            else
            {
                Console.WriteLine("[UsersController] No 'sub' or 'nameid' claim found in token.");
            }

            var result = await _mediator.Send(new GetUserProfileByEmailQuery(email, requesterId));
            if (result == null) return NotFound();
            return Ok(result);
        }
        [HttpPut("profile")]
        public async Task<IActionResult> UpdateProfile([FromBody] UpdateUserProfileCommand command)
        {
            // Extract userId from token to ensure security
            var userIdClaim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
            if (userIdClaim == null || !Guid.TryParse(userIdClaim.Value, out var userId))
            {
                return Unauthorized();
            }

            // Force command info to match token
            command.UserId = userId;

            var result = await _mediator.Send(command);
            if (!result) return NotFound();
            return Ok();
        }

        /// <summary>
        /// Register a device token (FCM) for push notifications.
        /// </summary>
        [HttpPost("device-token")]
        [Authorize]
        public async Task<IActionResult> RegisterDeviceToken([FromBody] RegisterDeviceTokenRequest request)
        {
            var userIdClaim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
            if (userIdClaim == null || !Guid.TryParse(userIdClaim.Value, out var identityId))
            {
                return Unauthorized();
            }

            var profile = await _userRepository.GetByIdentityIdAsync(identityId);
            if (profile == null) return NotFound(new { message = "User profile not found" });

            // Store the device token
            profile.DeviceToken = request.Token;
            profile.DevicePlatform = request.Platform;
            await _userRepository.UpdateAsync(profile);

            Console.WriteLine($"[Users] Device token registered for user {profile.Id}: {request.Token?.Substring(0, Math.Min(20, request.Token?.Length ?? 0))}...");

            return Ok(new { message = "Device token registered" });
        }

        /// <summary>
        /// Internal endpoint for Chat.API to fetch device tokens by identity IDs.
        /// Used for sending push notifications when new messages arrive.
        /// </summary>
        [HttpPost("device-tokens")]
        public async Task<IActionResult> GetDeviceTokens([FromBody] GetDeviceTokensRequest request)
        {
            if (request.IdentityIds == null || !request.IdentityIds.Any())
            {
                return Ok(new List<object>());
            }

            var guids = new List<Guid>();
            foreach (var id in request.IdentityIds)
            {
                if (Guid.TryParse(id, out var guid))
                {
                    guids.Add(guid);
                }
            }

            var profiles = await _userRepository.GetByIdentityIdsAsync(guids);

            var result = profiles
                .Where(p => !string.IsNullOrEmpty(p.DeviceToken))
                .Select(p => new
                {
                    identityId = p.IdentityId.ToString(),
                    fullName = p.FullName,
                    deviceToken = p.DeviceToken,
                    platform = p.DevicePlatform
                })
                .ToList();

            return Ok(result);
        }
    }

    public class RegisterDeviceTokenRequest
    {
        public string? Token { get; set; }
        public string? Platform { get; set; } // "android" or "ios"
    }

    public class GetDeviceTokensRequest
    {
        public List<string> IdentityIds { get; set; } = new();
    }
}
