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

        public async Task CreateUserProfileAsync(Guid identityId, string phoneOrEmail, string fullName)
        {
            var request = new
            {
                identityId = identityId,
                email = phoneOrEmail,
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

        public async Task<string?> GetUserFullNameAsync(Guid identityId)
        {
            try
            {
                var response = await _httpClient.GetAsync($"/api/v1/users/identity/{identityId}");
                if (response.IsSuccessStatusCode)
                {
                    var json = await response.Content.ReadAsStringAsync();
                    using var doc = JsonDocument.Parse(json);
                    if (doc.RootElement.TryGetProperty("fullName", out var nameProp))
                    {
                        return nameProp.GetString();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Warning: Failed to get user profile name: {ex.Message}");
            }
            return null;
        }
    }
}
