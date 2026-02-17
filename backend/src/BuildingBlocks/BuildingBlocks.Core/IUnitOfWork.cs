using System.Threading;
using System.Threading.Tasks;

namespace BuildingBlocks.Core
{
    public interface IUnitOfWork
    {
        Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
    }
}
