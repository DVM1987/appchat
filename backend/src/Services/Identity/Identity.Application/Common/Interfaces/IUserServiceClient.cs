namespace Identity.Application.Common.Interfaces
{
    public interface IUserServiceClient
    {
        Task CreateUserProfileAsync(Guid identityId, string phoneOrEmail, string fullName);
    }
}
