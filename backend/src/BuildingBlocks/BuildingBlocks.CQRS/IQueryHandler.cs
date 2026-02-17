using MediatR;
using System.Threading;
using System.Threading.Tasks;

namespace BuildingBlocks.CQRS
{
    public interface IQueryHandler<in TQuery, TResponse> : IRequestHandler<TQuery, TResponse>
        where TQuery : IQuery<TResponse>
    {
    }
}
