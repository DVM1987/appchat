namespace Identity.Application.Common.Interfaces
{
    public interface ITokenService
    {
        string GenerateToken(Guid userId, string fullName, string email);
    }
}
