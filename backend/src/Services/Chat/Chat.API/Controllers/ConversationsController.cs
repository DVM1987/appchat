using Chat.Application.Features.Conversations;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Chat.API.Models;
using Chat.Domain.Entities;

namespace Chat.API.Controllers
{
    [ApiController]
    [Route("api/v1/[controller]")]
    public class ConversationsController : ControllerBase
    {
        private readonly IMediator _mediator;
        private readonly IHubContext<Hubs.ChatHub> _hubContext;
        private readonly Chat.Domain.Interfaces.IChatRepository _repository;

        public ConversationsController(
            IMediator mediator,
            IHubContext<Hubs.ChatHub> hubContext,
            Chat.Domain.Interfaces.IChatRepository repository)
        {
            _mediator = mediator;
            _hubContext = hubContext;
            _repository = repository;
        }

        [HttpPost]
        public async Task<IActionResult> CreateConversation([FromBody] CreateConversationCommand command)
        {
            var userId = User.FindFirst("sub")?.Value 
                      ?? User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            var createCommand = command with { CreatorId = userId };
            var id = await _mediator.Send(createCommand);

            // Notify participants via SignalR
            var conversation = await _repository.GetConversationAsync(id);
            if (conversation != null)
            {
                var dto = new ConversationDto
                {
                    Id = conversation.Id,
                    Name = conversation.Name,
                    IsGroup = conversation.IsGroup,
                    ParticipantIds = conversation.ParticipantIds,
                    CreatorId = conversation.CreatorId ?? conversation.ParticipantIds.FirstOrDefault(),
                    Description = conversation.Description,
                    InviteToken = conversation.InviteToken,
                    LastMessage = conversation.LastMessageContent,
                    LastMessageTime = conversation.LastMessageTime ?? conversation.CreatedAt,
                    UnreadCount = 0
                };

                await _hubContext.Clients.Users(conversation.ParticipantIds).SendAsync("ConversationUpdated", dto);
                await _hubContext.Clients.Users(conversation.ParticipantIds).SendAsync("ConversationCreated", dto);
            }

            return CreatedAtAction(nameof(GetById), new { id = id }, new { id = id });
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(string id)
        {
            // Implement GetById query if needed, or just return Ok for now 
            // Skipping detailed implementation for brevity as it was not in the immediate plan
            var conversation = await _repository.GetConversationAsync(id);
            if (conversation == null) return NotFound();
            return Ok(conversation);
        }

        [HttpGet]
        public async Task<IActionResult> GetMyConversations([FromQuery] string userId)
        {
            var result = await _mediator.Send(new GetConversationsQuery(userId));
            return Ok(result);
        }

        [HttpPost("{id}/participants")]
        public async Task<IActionResult> AddParticipants(string id, [FromBody] AddParticipantsRequest request)
        {
            var adminId = User.FindFirst("sub")?.Value 
                       ?? User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            var result = await _mediator.Send(new AddParticipantsCommand(id, request.ParticipantIds, request.ParticipantNames, adminId));
            
            if (result.Success)
            {
                await NotifyConversationUpdate(id, result.SystemMessageContent);
                return Ok(new { message = "Participants added successfully" });
            }
            
            return BadRequest(new { message = "Failed to add participants" });
        }

        [HttpDelete("{id}/participants/{participantId}")]
        public async Task<IActionResult> RemoveParticipant(string id, string participantId, [FromQuery] string name)
        {
            var adminId = User.FindFirst("sub")?.Value 
                       ?? User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            var result = await _mediator.Send(new RemoveParticipantCommand(id, participantId, name, adminId));
            
            if (result.Success)
            {
                await NotifyConversationUpdate(id, result.SystemMessageContent, participantId);
                return Ok(new { message = "Participant removed successfully" });
            }
            
            return BadRequest(new { message = "Failed to remove participant" });
        }

        [HttpPost("join")]
        public async Task<IActionResult> JoinConversation([FromQuery] string token, [FromQuery] string name)
        {
            var userId = User.FindFirst("sub")?.Value 
                      ?? User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            var result = await _mediator.Send(new JoinConversationCommand(token, userId, name));
            
            if (result.Success)
            {
                await NotifyConversationUpdate(result.ConversationId!, result.SystemMessageContent);
                return Ok(new { conversationId = result.ConversationId });
            }
            
            return BadRequest(new { message = "Invalid invite token or failed to join" });
        }

        [HttpPost("{id}/leave")]
        public async Task<IActionResult> LeaveConversation(string id, [FromQuery] string name)
        {
            var userId = User.FindFirst("sub")?.Value 
                      ?? User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            var result = await _mediator.Send(new LeaveConversationCommand(id, userId, name));
            
            if (result.Success)
            {
                await NotifyConversationUpdate(id, result.SystemMessageContent);
                return Ok(new { message = "Left conversation successfully" });
            }
            
            return BadRequest(new { message = "Failed to leave conversation" });
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateConversation(string id, [FromBody] UpdateConversationRequest request)
        {
            var userId = User.FindFirst("sub")?.Value 
                      ?? User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            
            var updatedByName = request.UpdatedByName ?? "Quản trị viên";

            var command = new UpdateConversationCommand(id, request.Name, request.Description, request.AvatarUrl, userId, updatedByName);
            var result = await _mediator.Send(command);

            if (result.Success)
            {
                await NotifyConversationUpdate(id, result.SystemMessageContent);
                return Ok(new { message = "Group updated successfully" });
            }

            return BadRequest(new { message = result.ErrorMessage ?? "Failed to update group" });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DisbandConversation(string id)
        {
            var adminId = User.FindFirst("sub")?.Value 
                       ?? User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            var result = await _mediator.Send(new DisbandConversationCommand(id, adminId));
            
            if (result.Success)
            {
                // Notify all participants that the conversation is gone
                if (result.ParticipantIds != null)
                {
                    await _hubContext.Clients.Users(result.ParticipantIds).SendAsync("ConversationDeleted", id);
                }
                return Ok(new { message = "Group disbanded successfully" });
            }
            
            return BadRequest(new { message = "Failed to disband group" });
        }

        private async Task NotifyConversationUpdate(string id, string? systemMessageContent, string? removedParticipantId = null)
        {
            var conversation = await _repository.GetConversationAsync(id);
            if (conversation != null)
            {
                var dto = new ConversationDto
                {
                    Id = conversation.Id,
                    Name = conversation.Name,
                    IsGroup = conversation.IsGroup,
                    ParticipantIds = conversation.ParticipantIds,
                    CreatorId = conversation.CreatorId ?? conversation.ParticipantIds.FirstOrDefault(),
                    Description = conversation.Description,
                    InviteToken = conversation.InviteToken,
                    LastMessage = conversation.LastMessageContent,
                    LastMessageTime = conversation.LastMessageTime ?? conversation.CreatedAt,
                    UnreadCount = 0
                };

                // Notify current participants
                await _hubContext.Clients.Users(conversation.ParticipantIds).SendAsync("ConversationUpdated", dto);

                // If someone was removed, notify them as well so their UI updates (e.g., they get kicked out)
                if (removedParticipantId != null)
                {
                    await _hubContext.Clients.User(removedParticipantId).SendAsync("ConversationUpdated", dto);
                }

                // Broadcast system message
                if (!string.IsNullOrEmpty(systemMessageContent))
                {
                    var systemMessage = new 
                    {
                        Id = Guid.NewGuid().ToString(),
                        ConversationId = id,
                        SenderId = "system",
                        Content = systemMessageContent,
                        Type = (int)MessageType.System,
                        CreatedAt = DateTime.UtcNow,
                        ReadBy = new List<string> { "system" }
                    };
                    await _hubContext.Clients.Group(id).SendAsync("ReceiveMessage", systemMessage);
                }
            }
        }
    }
}
