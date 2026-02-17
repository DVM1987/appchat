using BuildingBlocks.CQRS;
using Identity.Application.Common.Interfaces;
using MediatR;
using BCrypt.Net;

namespace Identity.Application.Features.Auth
{
    public class LoginCommandHandler : ICommandHandler<LoginCommand, LoginResponse>
    {
        private readonly IUserRepository _userRepository;
        private readonly ITokenService _tokenService;

        public LoginCommandHandler(IUserRepository userRepository, ITokenService tokenService)
        {
            _userRepository = userRepository;
            _tokenService = tokenService;
        }

        public async Task<LoginResponse> Handle(LoginCommand request, CancellationToken cancellationToken)
        {
            // 1. Find user
            var normalizedEmail = request.Email.ToLowerInvariant();
            Console.WriteLine($"[Login] Attempting login for: {normalizedEmail}");
            var user = await _userRepository.GetByEmailAsync(normalizedEmail);
            if (user == null)
            {
                Console.WriteLine($"[Login] User not found: {request.Email}");
                throw new Exception("Invalid credentials");
            }

            // 2. Verify Password
            Console.WriteLine($"[Login] Found user {user.Id}. Hash: {user.PasswordHash}");
            Console.WriteLine($"[Login] Verifying password. Input length: {request.Password?.Length ?? 0}");
            
            bool verified = BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash);
            if (!verified)
            {
                Console.WriteLine($"[Login] Password verification failed for {request.Email}");
                throw new Exception("Invalid credentials");
            }

            // 3. Generate Token
            var token = _tokenService.GenerateToken(user.Id, user.FullName, user.Email);

            // 4. Return
            return new LoginResponse(token, 3600); // 1 hour
        }
    }
}
