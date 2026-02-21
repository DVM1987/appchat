using Identity.Application.Common.Interfaces;
using Identity.Domain.Entities;
using Identity.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Identity.Infrastructure.Repositories
{
    public class OtpRepository : IOtpRepository
    {
        private readonly IdentityDbContext _context;

        public OtpRepository(IdentityDbContext context)
        {
            _context = context;
        }

        public async Task SaveAsync(OtpEntry otp)
        {
            await _context.OtpEntries.AddAsync(otp);
            await _context.SaveChangesAsync();
        }

        public async Task<OtpEntry?> GetLatestAsync(string phoneNumber)
        {
            return await _context.OtpEntries
                .Where(o => o.PhoneNumber == phoneNumber && !o.IsUsed)
                .OrderByDescending(o => o.CreatedAt)
                .FirstOrDefaultAsync();
        }
    }
}
