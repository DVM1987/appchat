namespace Chat.API.Models
{
    public class UpdateConversationRequest
    {
        public string? Name { get; set; }
        public string? Description { get; set; }
        public string? AvatarUrl { get; set; }
        public string? UpdatedByName { get; set; }
    }
}
