namespace BuildingBlocks.EventBus.Events
{
    public record UserRegisteredEvent(Guid IdentityId, string Email, string FullName);
}
