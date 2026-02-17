using MassTransit;
using MediatR;
using BuildingBlocks.EventBus; 
using Microsoft.Extensions.Logging;

namespace User.Application.IntegrationEvents
{
    // Need to define the event structure exactly as published by Identity Service
    // Or reference a shared contract library. Since we don't have a shared contract lib yet 
    // (BuildingBlocks.EventBus has base class but not specific events), 
    // we should define the event here or use the same definition.
    // Let's assume Identity Service publishes UserRegisteredEvent.
    
    public record UserRegisteredEvent(Guid IdentityId, string Email, string FullName);

    public class UserRegisteredConsumer : IConsumer<UserRegisteredEvent>
    {
        private readonly IMediator _mediator;
        private readonly ILogger<UserRegisteredConsumer> _logger;

        public UserRegisteredConsumer(IMediator mediator, ILogger<UserRegisteredConsumer> logger)
        {
            _mediator = mediator;
            _logger = logger;
        }

        public async Task Consume(ConsumeContext<UserRegisteredEvent> context)
        {
            _logger.LogInformation("Consuming UserRegisteredEvent: {IdentityId}", context.Message.IdentityId);
            
            var command = new Features.Profiles.CreateUserProfileCommand(
                context.Message.IdentityId, 
                context.Message.FullName, 
                context.Message.Email
            );

            await _mediator.Send(command);
        }
    }
}
