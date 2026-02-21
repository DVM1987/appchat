using Identity.Domain.Entities;

namespace Identity.Application.Common.Interfaces
{
    public interface IOtpRepository
    {
        Task SaveAsync(OtpEntry otp);
        Task<OtpEntry?> GetLatestAsync(string phoneNumber);
    }
}
