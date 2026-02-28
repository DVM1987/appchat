using Chat.Domain.Entities;

namespace Chat.Domain.Interfaces
{
    public interface IChatRepository
    {
        Task<Conversation> GetConversationAsync(string id);
        Task<List<Conversation>> GetConversationsByUserIdAsync(string userId);
        Task CreateConversationAsync(Conversation conversation);
        Task UpdateConversationAsync(Conversation conversation);
        Task DeleteConversationAsync(string id);
        
        Task<Message> GetMessageAsync(string id);
        Task<List<Message>> GetMessagesAsync(string conversationId, string userId, int skip, int take);
        Task<Message?> GetLatestMessageAsync(string conversationId);
        Task<Conversation?> GetConversationByParticipantsAsync(List<string> participantIds, bool isGroup);
        Task<Conversation?> GetConversationByInviteTokenAsync(string token);
        Task SaveMessageAsync(Message message);
        Task UpdateMessageAsync(Message message);
        Task DeleteMessageAsync(string messageId);
        Task MarkMessageDeletedForUserAsync(string messageId, string userId);
        Task DeleteMessagesByConversationIdAsync(string conversationId);
        Task MarkMessagesAsReadAsync(string conversationId, string userId);
        Task<int> GetUnreadMessageCountAsync(string conversationId, string userId);
        Task<int> GetTotalUnreadCountAsync(string userId);
    }
}
