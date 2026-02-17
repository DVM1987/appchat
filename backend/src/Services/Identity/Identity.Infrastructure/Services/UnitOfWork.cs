using BuildingBlocks.Core;
using Identity.Infrastructure.Persistence;
using System.Threading;
using System.Threading.Tasks;

namespace Identity.Infrastructure.Services
{
    // Simple adapter to expose SaveChangesAsync via IUnitOfWork interface
    // Ideally this is handled via repository pattern or cleaner abstraction
    public class UnitOfWork : IUnitOfWork
    {
        private readonly IdentityDbContext _context;

        public UnitOfWork(IdentityDbContext context)
        {
            _context = context;
        }

        public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        {
            return await _context.SaveChangesAsync(cancellationToken);
        }
    }
}
