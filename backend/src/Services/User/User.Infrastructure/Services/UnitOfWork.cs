using System.Threading;
using System.Threading.Tasks;
using User.Domain.Interfaces;
using User.Infrastructure.Persistence;

namespace User.Infrastructure.Services
{
    public class UnitOfWork : IUnitOfWork
    {
        private readonly UserDbContext _context;

        public UnitOfWork(UserDbContext context)
        {
            _context = context;
        }

        public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        {
            return await _context.SaveChangesAsync(cancellationToken);
        }
    }
}
