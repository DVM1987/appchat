using BuildingBlocks.Core;
using MongoDB.Bson.Serialization.Attributes;

namespace Chat.Domain.Entities
{
    [BsonIgnoreExtraElements]
    public class Conversation : Entity<string> // MongoDB ObjectId as string
    {
        public string Name { get; private set; }
        public bool IsGroup { get; private set; }
        public List<string> ParticipantIds { get; private set; } = new();
        
        public string? LastMessageId { get; private set; }
        public string? LastMessageContent { get; private set; }
        public DateTime? LastMessageTime { get; private set; }
        
        public DateTime CreatedAt { get; private set; }
        public DateTime UpdatedAt { get; private set; }

        public string? CreatorId { get; private set; }
        public string? Description { get; private set; }
        public string? AvatarUrl { get; private set; }
        public string? InviteToken { get; private set; }
        
        // Private constructor for MongoDB deserialization
        [BsonConstructor]
        private Conversation() { }

        public Conversation(List<string> participantIds, bool isGroup, string? name = null, string? creatorId = null)
        {
            Id = Guid.NewGuid().ToString(); 
            ParticipantIds = participantIds;
            IsGroup = isGroup;
            Name = name ?? (isGroup ? "New Group" : "Chat");
            CreatorId = creatorId ?? participantIds.FirstOrDefault();
            CreatedAt = DateTime.UtcNow;
            UpdatedAt = DateTime.UtcNow;
            
            if (isGroup)
            {
                InviteToken = Guid.NewGuid().ToString("N").Substring(0, 12);
            }
        }

        public void UpdateInfo(string? name, string? description, string? avatarUrl)
        {
            if (!string.IsNullOrEmpty(name)) Name = name;
            Description = description;
            AvatarUrl = avatarUrl;
            UpdatedAt = DateTime.UtcNow;
        }

        public void GenerateNewInviteToken()
        {
            InviteToken = Guid.NewGuid().ToString("N").Substring(0, 12);
            UpdatedAt = DateTime.UtcNow;
        }

        public void SetDescription(string description)
        {
            Description = description;
            UpdatedAt = DateTime.UtcNow;
        }

        public void UpdateLastMessage(string messageId, string content, DateTime time)
        {
            LastMessageId = messageId;
            LastMessageContent = content;
            LastMessageTime = time;
            UpdatedAt = time;
        }

        public void ClearLastMessage()
        {
            LastMessageId = null;
            LastMessageContent = null;
            LastMessageTime = null;
            UpdatedAt = DateTime.UtcNow;
        }
    }
}
