using Chat.Application.Features.Messages;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Chat.API.Hubs;
using Microsoft.AspNetCore.Authorization;
using Chat.Application.Features.Conversations;

namespace Chat.API.Controllers
{
    [ApiController]
    [Authorize]
    [Route("api/v1/conversations/{conversationId}/[controller]")]
    public class MessagesController : ControllerBase
    {
        private readonly IMediator _mediator;
        private readonly IHubContext<ChatHub> _hubContext;
        private readonly Chat.Domain.Interfaces.IChatRepository _repository; // Inject Repository

        public MessagesController(IMediator mediator, IHubContext<ChatHub> hubContext, Chat.Domain.Interfaces.IChatRepository repository)
        {
            _mediator = mediator;
            _hubContext = hubContext;
            _repository = repository;
        }

        private string? GetUserId()
        {
            return User.FindFirst("sub")?.Value ?? 
                   User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        }

        [HttpPost]
        public async Task<IActionResult> SendMessage(string conversationId, [FromBody] SendMessageCommand command)
        {
            if (command.ConversationId != conversationId)
            {
                return BadRequest("Conversation mismatch");
            }

            var userId = GetUserId();
            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized();
            }
            
            // Override senderId with authenticated user to prevent spoofing
            var secureCommand = command with { SenderId = userId };

            var messageId = await _mediator.Send(secureCommand);

            // Broadcast to all participants (replaces previous Group broadcast to avoid double delivery)
            var conversation = await _repository.GetConversationAsync(conversationId);
            if (conversation != null && conversation.ParticipantIds.Any())
            {
                // Find the saved message to get the exact fields
                var savedMessage = await _repository.GetMessageAsync(messageId);

                await _hubContext.Clients.Users(conversation.ParticipantIds).SendAsync("ReceiveMessage", new
                {
                    // Keep a single camelCase contract for Flutter client
                    id = savedMessage?.Id ?? messageId,
                    conversationId = savedMessage?.ConversationId ?? conversationId,
                    senderId = savedMessage?.SenderId ?? userId,
                    content = savedMessage?.Content ?? command.Content,
                    type = savedMessage != null ? (int)savedMessage.Type : command.Type,
                    createdAt = savedMessage?.CreatedAt ?? DateTime.UtcNow,
                    replyToId = savedMessage?.ReplyToId,
                    replyToContent = savedMessage?.ReplyToContent,
                    readBy = savedMessage?.ReadBy ?? new List<string> { userId },
                    reactions = savedMessage?.Reactions ?? new List<Chat.Domain.Entities.MessageReaction>()
                });
            }

            return Ok(new { MessageId = messageId });
        }

        [HttpGet]
        public async Task<IActionResult> GetMessages(string conversationId, [FromQuery] int skip = 0, [FromQuery] int take = 20)
        {
            var userId = GetUserId();
            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized();
            }

            var result = await _mediator.Send(new GetMessagesQuery(conversationId, userId, skip, take));
            return Ok(result);
        }

        [HttpDelete("{messageId}")]
        public async Task<IActionResult> DeleteMessage(
            string conversationId,
            string messageId,
            [FromQuery] bool forEveryone = false)
        {
            var userId = GetUserId();
            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized();
            }

            var conversation = await _repository.GetConversationAsync(conversationId);
            if (conversation == null)
            {
                return NotFound("Conversation not found");
            }

            if (!conversation.ParticipantIds.Contains(userId))
            {
                return Forbid();
            }

            var message = await _repository.GetMessageAsync(messageId);
            if (message == null || message.ConversationId != conversationId)
            {
                return NotFound("Message not found");
            }

            if (forEveryone)
            {
                if (!string.Equals(message.SenderId, userId, StringComparison.OrdinalIgnoreCase))
                {
                    return Forbid("Only sender can delete for everyone");
                }

                message.MarkDeletedForEveryone(userId);
                await _repository.UpdateMessageAsync(message);

                if (conversation.LastMessageId == messageId)
                {
                    conversation.UpdateLastMessage(
                        messageId,
                        "Tin nhắn đã bị xoá",
                        DateTime.UtcNow);
                    await _repository.UpdateConversationAsync(conversation);
                    await _hubContext.Clients.Users(conversation.ParticipantIds).SendAsync(
                        "ConversationUpdated",
                        new ConversationDto
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
                        });
                }

                await _hubContext.Clients.Users(conversation.ParticipantIds).SendAsync(
                    "MessageDeleted",
                    new
                    {
                        conversationId,
                        messageId,
                        scope = "everyone",
                        userId,
                        isDeletedForEveryone = true,
                        deletedForEveryoneByUserId = userId
                    });
            }
            else
            {
                await _repository.MarkMessageDeletedForUserAsync(messageId, userId);
                await _hubContext.Clients.User(userId).SendAsync(
                    "MessageDeleted",
                    new
                    {
                        conversationId,
                        messageId,
                        scope = "me",
                        userId
                    });
            }

            return Ok(new { messageId, forEveryone });
        }

        [HttpPost("{messageId}/reactions")]
        public async Task<IActionResult> ReactToMessage(string conversationId, string messageId, [FromBody] ReactToMessageRequest request)
        {
            var userId = GetUserId();
            if (string.IsNullOrEmpty(userId))
            {
                Console.WriteLine("[MessagesController] ReactToMessage: Unauthorized");
                return Unauthorized();
            }

            var command = new ReactToMessageCommand(messageId, userId, request.ReactionType);
            await _mediator.Send(command);

            // Fetch conversation for broadcast
            var conversation = await _repository.GetConversationAsync(conversationId);
            
            if (conversation != null && conversation.ParticipantIds != null && conversation.ParticipantIds.Any())
            {
                // Ensure messageId is sent as string and camelCase
                var broadcastData = new
                {
                    conversationId = conversationId,
                    messageId = messageId,
                    userId = userId,
                    reactionType = request.ReactionType,
                    reactedAt = DateTime.UtcNow
                };

                Console.WriteLine($"[MessagesController] Broadcasting Reaction: Msg={messageId}, User={userId}, Type={request.ReactionType}");
                
                await _hubContext.Clients.Users(conversation.ParticipantIds).SendAsync("MessageReacted", broadcastData);
            }

            return Ok();
        }
    }

    public class ReactToMessageRequest
    {
        public string ReactionType { get; set; }
    }
}
