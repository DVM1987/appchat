using BuildingBlocks.Core;
using BuildingBlocks.CQRS;
using MassTransit;
using Identity.Application.Common.Interfaces;
using Identity.Domain.Entities;
using MediatR;
using BCrypt.Net;

namespace Identity.Application.Features.Auth
{
    public class RegisterUserCommandHandler : ICommandHandler<RegisterUserCommand, Guid>
    {
        private readonly IUnitOfWork _unitOfWork;
        // In a real app, use IRepository<User>
        // But for simplicity/speed, we might need access to DbContext or a generic repository
        // Since I haven't defined IRepository in BuildingBlocks, I'll assume we can inject custom repositories or DbContext if needed.
        // However, Clean Architecture purists usually hide DbContext.
        // Let's assume IApplicationDbContext interface or similar, OR just use the DbContext directly for now through DI in infrastructure
        // But Application shouldn't reference Infrastructure.
        // So I need an Interface for the DbContext or User Repository.
        
        // Let's define IUserRepository in Application/Common/Interfaces
        private readonly IUserRepository _userRepository;
        private readonly IUserServiceClient _userServiceClient;

        public RegisterUserCommandHandler(IUserRepository userRepository, IUnitOfWork unitOfWork, IUserServiceClient userServiceClient)
        {
            _userRepository = userRepository;
            _unitOfWork = unitOfWork;
            _userServiceClient = userServiceClient;
        }

        public async Task<Guid> Handle(RegisterUserCommand request, CancellationToken cancellationToken)
        {
            // Check if email exists
            var normalizedEmail = request.Email.ToLowerInvariant();
            var isUnique = await _userRepository.IsEmailUniqueAsync(normalizedEmail);
            if (!isUnique)
            {
                throw new Exception("Email already exists.");
            }

            // Hash password with BCrypt
            var passwordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);
            
            var user = new User(normalizedEmail, passwordHash, request.FullName);
            await _userRepository.AddAsync(user);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            // Auto-create user profile via HTTP call
            try
            {
                await _userServiceClient.CreateUserProfileAsync(user.Id, user.Email, user.FullName);
            }
            catch (Exception ex)
            {
                // Log error but don't fail registration
                Console.WriteLine($"Warning: Failed to create user profile: {ex.Message}");
            }

            return user.Id;
        }
    }
    
    // I check I need IUserRepository
}
