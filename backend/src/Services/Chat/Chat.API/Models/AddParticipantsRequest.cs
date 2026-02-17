using System.Collections.Generic;

namespace Chat.API.Models
{
    public class AddParticipantsRequest
    {
        public List<string> ParticipantIds { get; set; } = new();
        public List<string> ParticipantNames { get; set; } = new();
    }
}
