using MassTransit;
using System.Threading.Tasks;
using System;

namespace EventPublisher
{
    using User.Application.IntegrationEvents;

    public class Program
    {
        public static async Task Main(string[] args)
        {
            Console.WriteLine("Starting EventPublisher...");
            var busControl = Bus.Factory.CreateUsingRabbitMq(cfg =>
            {
                cfg.Host("rabbitmq", "/", h =>
                {
                    h.Username("guest");
                    h.Password("guest");
                });
            });

            await busControl.StartAsync();
            Console.WriteLine("Bus started.");

            try
            {
                var identityId = Guid.NewGuid();
                var email = $"manual-user-{DateTime.UtcNow.Ticks}@example.com";
                var fullName = "Manual User";

                await busControl.Publish(new UserRegisteredEvent(identityId, email, fullName));

                Console.WriteLine($"Published UserRegisteredEvent: ID={identityId}, Email={email}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
            finally
            {
                await busControl.StopAsync();
            }
        }
    }
}

namespace User.Application.IntegrationEvents
{
    public record UserRegisteredEvent(Guid IdentityId, string Email, string FullName);
}
