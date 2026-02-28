using Chat.Domain.Entities;
using Chat.Domain.Interfaces;
using Chat.Infrastructure.Persistence;
using MongoDB.Driver;

namespace Chat.Infrastructure.Repositories
{
    public class ChatRepository : IChatRepository
    {
        private readonly ChatContext _context;

        public ChatRepository(ChatContext context)
        {
            _context = context;
        }

        public async Task CreateConversationAsync(Conversation conversation)
        {
            await _context.Conversations.InsertOneAsync(conversation);
        }

        public async Task<Conversation> GetConversationAsync(string id)
        {
            return await _context.Conversations.Find(c => c.Id == id).FirstOrDefaultAsync();
        }

        public async Task<List<Conversation>> GetConversationsByUserIdAsync(string userId)
        {
            // Find conversations where ParticipantIds contains userId
            // Filter using string directly
            return await _context.Conversations.Find(c => c.ParticipantIds.Contains(userId)).ToListAsync();
        }

        public async Task<Message> GetMessageAsync(string id)
        {
            return await _context.Messages.Find(m => m.Id == id).FirstOrDefaultAsync();
        }

        public async Task<List<Message>> GetMessagesAsync(string conversationId, string userId, int skip, int take)
        {
            var filter = Builders<Message>.Filter.And(
                Builders<Message>.Filter.Eq(m => m.ConversationId, conversationId),
                Builders<Message>.Filter.Ne("DeletedForUserIds", userId)
            );

            return await _context.Messages.Find(filter)
                .SortByDescending(m => m.CreatedAt) // Usually chat is newest last, but fetching usually newest first for paging up
                .Skip(skip)
                .Limit(take)
                .ToListAsync();
        }

        public async Task<Message?> GetLatestMessageAsync(string conversationId)
        {
            return await _context.Messages
                .Find(m => m.ConversationId == conversationId)
                .SortByDescending(m => m.CreatedAt)
                .FirstOrDefaultAsync();
        }

        public async Task<Conversation?> GetConversationByParticipantsAsync(List<string> participantIds, bool isGroup)
        {
            // Ensure ids are sorted for consistent comparison
            var sortedIds = participantIds.OrderBy(x => x).ToList();
            
            var filter = Builders<Conversation>.Filter;
            // Since we are using strings, we can just use Eq on the list if the order is guaranteed
            var query = filter.And(
                filter.Eq(c => c.IsGroup, isGroup),
                filter.Eq(c => c.ParticipantIds, sortedIds)
            );
            
            return await _context.Conversations.Find(query).FirstOrDefaultAsync();
        }

        public async Task<Conversation?> GetConversationByInviteTokenAsync(string token)
        {
            return await _context.Conversations.Find(c => c.InviteToken == token).FirstOrDefaultAsync();
        }

        public async Task SaveMessageAsync(Message message)
        {
            await _context.Messages.InsertOneAsync(message);
        }

        public async Task UpdateMessageAsync(Message message)
        {
            var result = await _context.Messages.ReplaceOneAsync(m => m.Id == message.Id, message);
            Console.WriteLine($"[ChatRepository] UpdateMessageAsync: Matched {result.MatchedCount}, Modified {result.ModifiedCount}. Reactions count: {message.Reactions.Count}");
        }

        public async Task DeleteMessageAsync(string messageId)
        {
            await _context.Messages.DeleteOneAsync(m => m.Id == messageId);
        }

        public async Task MarkMessageDeletedForUserAsync(string messageId, string userId)
        {
            var filter = Builders<Message>.Filter.Eq(m => m.Id, messageId);
            var update = Builders<Message>.Update.AddToSet("DeletedForUserIds", userId);
            await _context.Messages.UpdateOneAsync(filter, update);
        }

        public async Task DeleteMessagesByConversationIdAsync(string conversationId)
        {
            await _context.Messages.DeleteManyAsync(m => m.ConversationId == conversationId);
        }

        public async Task UpdateConversationAsync(Conversation conversation)
        {
            await _context.Conversations.ReplaceOneAsync(c => c.Id == conversation.Id, conversation);
        }

        public async Task DeleteConversationAsync(string id)
        {
            await _context.Conversations.DeleteOneAsync(c => c.Id == id);
        }

        public async Task MarkMessagesAsReadAsync(string conversationId, string userId)
        {
            var filter = Builders<Message>.Filter.And(
                Builders<Message>.Filter.Eq(m => m.ConversationId, conversationId),
                Builders<Message>.Filter.Ne(m => m.SenderId, userId),
                Builders<Message>.Filter.Ne("ReadBy", userId)
            );

            var update = Builders<Message>.Update.AddToSet("ReadBy", userId);

            var result = await _context.Messages.UpdateManyAsync(filter, update);
            Console.WriteLine($"[ChatRepository] MarkMessagesAsReadAsync updated {result.ModifiedCount} messages for user {userId}");
        }

        public async Task<int> GetUnreadMessageCountAsync(string conversationId, string userId)
        {
            var filter = Builders<Message>.Filter.And(
                Builders<Message>.Filter.Eq(m => m.ConversationId, conversationId),
                Builders<Message>.Filter.Ne(m => m.SenderId, userId),
                Builders<Message>.Filter.Ne("ReadBy", userId)
            );
            return (int)await _context.Messages.CountDocumentsAsync(filter);
        }

        public async Task<int> GetTotalUnreadCountAsync(string userId)
        {
            // Get all conversation IDs this user belongs to
            var conversations = await _context.Conversations
                .Find(c => c.ParticipantIds.Contains(userId))
                .Project(c => c.Id)
                .ToListAsync();

            if (!conversations.Any()) return 0;

            // Count all unread messages across all conversations in a single query
            var filter = Builders<Message>.Filter.And(
                Builders<Message>.Filter.In(m => m.ConversationId, conversations),
                Builders<Message>.Filter.Ne(m => m.SenderId, userId),
                Builders<Message>.Filter.Ne("ReadBy", userId)
            );
            return (int)await _context.Messages.CountDocumentsAsync(filter);
        }
    }
}
