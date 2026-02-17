using System.Threading;
using System.Threading.Tasks;

namespace BuildingBlocks.EventBus
{
    public interface IEventBus
    {
        Task PublishAsync<T>(T @event, CancellationToken cancellationToken = default) 
            where T : IntegrationEvent;
    }
}
