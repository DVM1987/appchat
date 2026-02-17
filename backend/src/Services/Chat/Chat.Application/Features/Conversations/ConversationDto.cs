namespace Chat.Application.Features.Conversations
{
    public class ConversationDto
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public bool IsGroup { get; set; }
        public List<string> ParticipantIds { get; set; }
        public string? CreatorId { get; set; }
        public string? Description { get; set; }
        public string? InviteToken { get; set; }
        public string? LastMessage { get; set; }
        public DateTime? LastMessageTime { get; set; }
        public int UnreadCount { get; set; }
    }
}
