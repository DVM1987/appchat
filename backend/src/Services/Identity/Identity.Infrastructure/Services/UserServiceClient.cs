using System.Text;
using System.Text.Json;
using Identity.Application.Common.Interfaces;

namespace Identity.Infrastructure.Services
{
    public class UserServiceClient : IUserServiceClient
    {
        private readonly HttpClient _httpClient;

        public UserServiceClient(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task CreateUserProfileAsync(Guid identityId, string email, string fullName)
        {
            var request = new
            {
                identityId = identityId,
                email = email,
                fullName = fullName
            };

            var json = JsonSerializer.Serialize(request);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync("/api/v1/users", content);
            
            if (!response.IsSuccessStatusCode)
            {
                var error = await response.Content.ReadAsStringAsync();
                throw new Exception($"Failed to create user profile: {response.StatusCode} - {error}");
            }
        }
    }
}
