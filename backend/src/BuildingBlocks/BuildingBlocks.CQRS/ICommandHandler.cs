using MediatR;
using System.Threading;
using System.Threading.Tasks;

namespace BuildingBlocks.CQRS
{
    public interface ICommandHandler<in TCommand> : IRequestHandler<TCommand, Unit>
        where TCommand : ICommand
    {
    }

    public interface ICommandHandler<in TCommand, TResponse> : IRequestHandler<TCommand, TResponse>
        where TCommand : ICommand<TResponse>
    {
    }
}
