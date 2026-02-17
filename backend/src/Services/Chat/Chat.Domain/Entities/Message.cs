using BuildingBlocks.Core;
using MongoDB.Bson.Serialization.Attributes;

namespace Chat.Domain.Entities
{
    public class Message : Entity<string>
    {
        [BsonElement("ConversationId")]
        public string ConversationId { get; private set; }
        
        [BsonElement("SenderId")]
        public string SenderId { get; private set; }
        
        [BsonElement("Content")]
        public string Content { get; private set; }
        
        [BsonElement("Type")]
        public MessageType Type { get; private set; }
        
        [BsonElement("CreatedAt")]
        public DateTime CreatedAt { get; private set; }
        
        [BsonElement("ReadBy")]
        public List<string> ReadBy { get; private set; } = new();
        
        [BsonElement("Reactions")]
        public List<MessageReaction> Reactions { get; set; } = new();

        [BsonElement("DeletedForUserIds")]
        public List<string> DeletedForUserIds { get; private set; } = new();

        [BsonElement("IsDeletedForEveryone")]
        public bool IsDeletedForEveryone { get; private set; } = false;

        [BsonElement("DeletedForEveryoneByUserId")]
        public string? DeletedForEveryoneByUserId { get; private set; }

        [BsonElement("DeletedForEveryoneAt")]
        public DateTime? DeletedForEveryoneAt { get; private set; }

        [BsonElement("ReplyToId")]
        public string? ReplyToId { get; private set; }

        [BsonElement("ReplyToContent")]
        public string? ReplyToContent { get; private set; }

        [BsonElement("ReplyToSenderName")]
        public string? ReplyToSenderName { get; private set; }

        public Message(string conversationId, string senderId, string content, MessageType type, string? replyToId = null, string? replyToContent = null, string? replyToSenderName = null)
        {
            ConversationId = conversationId;
            SenderId = senderId;
            Content = content;
            Type = type;
            Id = Guid.NewGuid().ToString();
            CreatedAt = DateTime.UtcNow;
            ReadBy.Add(senderId);
            ReplyToId = replyToId;
            ReplyToContent = replyToContent;
            ReplyToSenderName = replyToSenderName;
        }

        public void MarkAsRead(string userId)
        {
            if (!ReadBy.Contains(userId))
            {
                ReadBy.Add(userId);
            }
        }

        public void AddReaction(string userId, string type)
        {
            if (Reactions == null)
            {
                Reactions = new List<MessageReaction>();
            }

            var existingReaction = Reactions.FirstOrDefault(r => r.UserId == userId);
            if (existingReaction != null)
            {
                if (existingReaction.Type == type)
                {
                    Reactions.Remove(existingReaction); // Toggle off if same reaction
                }
                else
                {
                    existingReaction.UpdateType(type); // Update if different
                }
            }
            else
            {
                Reactions.Add(new MessageReaction(userId, type));
            }
        }

        public void MarkDeletedForUser(string userId)
        {
            if (DeletedForUserIds == null)
            {
                DeletedForUserIds = new List<string>();
            }

            if (!DeletedForUserIds.Contains(userId))
            {
                DeletedForUserIds.Add(userId);
            }
        }

        public bool IsDeletedForUser(string userId)
        {
            return DeletedForUserIds != null && DeletedForUserIds.Contains(userId);
        }

        public void MarkDeletedForEveryone(string deletedByUserId)
        {
            IsDeletedForEveryone = true;
            DeletedForEveryoneByUserId = deletedByUserId;
            DeletedForEveryoneAt = DateTime.UtcNow;

            // Retain message shell for timeline but remove sensitive payload.
            Content = string.Empty;
            ReplyToId = null;
            ReplyToContent = null;
            ReplyToSenderName = null;
            Reactions = new List<MessageReaction>();
        }
    }

    public class MessageReaction
    {
        [BsonElement("UserId")]
        public string UserId { get; set; }
        
        [BsonElement("Type")]
        public string Type { get; set; }
        
        [BsonElement("ReactedAt")]
        public DateTime ReactedAt { get; set; }

        public MessageReaction() { }

        public MessageReaction(string userId, string type)
        {
            UserId = userId;
            Type = type;
            ReactedAt = DateTime.UtcNow;
        }

        public void UpdateType(string type)
        {
            Type = type;
            ReactedAt = DateTime.UtcNow;
        }
    }

    public enum MessageType
    {
        Text,
        Image,
        File,
        System,
        Voice
    }
}
