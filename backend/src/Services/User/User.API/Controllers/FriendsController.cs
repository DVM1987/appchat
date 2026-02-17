using System.Security.Claims;
using BuildingBlocks.CQRS;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using User.Application.Features.Friends;
using User.Domain.Interfaces;

namespace User.API.Controllers
{
    [ApiController]
    [Route("api/v1/[controller]")]
    [Authorize]
    public class FriendsController : ControllerBase
    {
        private readonly IMediator _mediator;
        private readonly IUserRepository _userRepository;
        private readonly Microsoft.AspNetCore.SignalR.IHubContext<Hubs.UserHub> _hubContext;

        public FriendsController(IMediator mediator, IUserRepository userRepository, Microsoft.AspNetCore.SignalR.IHubContext<Hubs.UserHub> hubContext)
        {
            _mediator = mediator;
            _userRepository = userRepository;
            _hubContext = hubContext;
        }

        private async Task<Guid> GetCurrentUserIdAsync()
        {
            var identityIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (identityIdClaim == null) 
                identityIdClaim = User.FindFirst("sub");
            
            if (identityIdClaim == null)
                throw new UnauthorizedAccessException("User not authenticated.");

            if (!Guid.TryParse(identityIdClaim.Value, out var identityId))
                throw new UnauthorizedAccessException("Invalid User ID in token.");

            var userProfile = await _userRepository.GetByIdentityIdAsync(identityId);
            if (userProfile == null)
                throw new Exception("User profile not found.");

            return userProfile.Id;
        }

        // Input DTOs
        public record SendFriendRequestRequest(Guid AddresseeId);
        public record AcceptFriendRequestRequest(Guid RequesterId);
        public record DeclineFriendRequestRequest(Guid FromUserId);

        [HttpPost("request")]
        public async Task<IActionResult> SendRequest([FromBody] SendFriendRequestRequest request)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            // Command Logic: Requester = CurrentUser, Addressee = Input
            var command = new SendFriendRequestCommand(currentUserId, request.AddresseeId);
            
            var success = await _mediator.Send(command);
            if (!success) return BadRequest("Request failed (already friends or pending).");

            // Broadcast real-time notification
            var addresseeProfile = await _userRepository.GetByIdAsync(request.AddresseeId);
            if (addresseeProfile != null)
            {
                var targetId = addresseeProfile.IdentityId.ToString();
                Console.WriteLine($"[FriendsController] Sending FriendRequestReceived to Group: {targetId}");
                await _hubContext.Clients.Group(targetId).SendAsync("FriendRequestReceived");
            }

            return Ok("Friend request sent.");
        }

        [HttpPost("accept")]
        public async Task<IActionResult> AcceptRequest([FromBody] AcceptFriendRequestRequest request)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            // Command Logic: Requester = Input, Addressee = CurrentUser
            var command = new AcceptFriendRequestCommand(request.RequesterId, currentUserId);

            var success = await _mediator.Send(command);
            if (!success) return BadRequest("Accept failed (no pending request found).");

            // Broadcast to the original requester that they are now friends
            var requesterProfile = await _userRepository.GetByIdAsync(request.RequesterId);
            if (requesterProfile != null)
            {
                await _hubContext.Clients.Group(requesterProfile.IdentityId.ToString()).SendAsync("FriendRequestAccepted");
            }

            return Ok("Friend request accepted.");
        }

        [HttpGet]
        public async Task<IActionResult> GetFriends()
        {
            var currentUserId = await GetCurrentUserIdAsync();
            var result = await _mediator.Send(new GetFriendsQuery(currentUserId));
            return Ok(result);
        }

        [HttpGet("pending")]
        public async Task<IActionResult> GetPendingRequests()
        {
            var currentUserId = await GetCurrentUserIdAsync();
            var result = await _mediator.Send(new GetPendingRequestsQuery(currentUserId));
            return Ok(result);
        }

        [HttpPost("decline")]
        public async Task<IActionResult> DeclineRequest([FromBody] DeclineFriendRequestRequest request)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            // Command Logic: UserId (Addressee) = CurrentUser, FromUserId (Requester) = Input
            var command = new DeclineFriendRequestCommand(currentUserId, request.FromUserId);

            var success = await _mediator.Send(command);
            if (!success) return BadRequest("Decline failed (no pending request found).");
            return Ok("Friend request declined.");
        }
    }
}
