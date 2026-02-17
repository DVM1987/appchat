namespace Chat.API.Models
{
    public class RemoveParticipantRequest
    {
        public string ParticipantId { get; set; } = string.Empty;
        public string ParticipantName { get; set; } = string.Empty;
    }
}
