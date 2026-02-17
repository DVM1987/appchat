using BuildingBlocks.Core;

namespace User.Domain.Interfaces
{
    // Inherit from shared IUnitOfWork if needed, or define specific one
    public interface IUnitOfWork : BuildingBlocks.Core.IUnitOfWork
    {
    }
}
