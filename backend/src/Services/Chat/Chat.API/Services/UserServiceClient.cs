using System.Text;
using System.Text.Json;

namespace Chat.API.Services
{
    /// <summary>
    /// HTTP client for calling User.API to fetch device tokens.
    /// Chat.API and User.API are separate microservices, so we
    /// use HTTP to communicate between them within the Docker network.
    /// </summary>
    public interface IUserServiceClient
    {
        Task<List<DeviceTokenInfo>> GetDeviceTokensAsync(List<string> identityIds);
    }

    public class UserServiceClient : IUserServiceClient
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<UserServiceClient> _logger;

        public UserServiceClient(HttpClient httpClient, ILogger<UserServiceClient> logger)
        {
            _httpClient = httpClient;
            _logger = logger;
        }

        public async Task<List<DeviceTokenInfo>> GetDeviceTokensAsync(List<string> identityIds)
        {
            try
            {
                var request = new { IdentityIds = identityIds };
                var json = JsonSerializer.Serialize(request);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("/api/v1/users/device-tokens", content);

                if (response.IsSuccessStatusCode)
                {
                    var responseBody = await response.Content.ReadAsStringAsync();
                    var tokens = JsonSerializer.Deserialize<List<DeviceTokenInfo>>(responseBody, new JsonSerializerOptions
                    {
                        PropertyNameCaseInsensitive = true
                    });
                    return tokens ?? new List<DeviceTokenInfo>();
                }

                _logger.LogWarning("[UserServiceClient] Failed to get device tokens: {StatusCode}", response.StatusCode);
                return new List<DeviceTokenInfo>();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[UserServiceClient] Error getting device tokens");
                return new List<DeviceTokenInfo>();
            }
        }
    }

    public class DeviceTokenInfo
    {
        public string IdentityId { get; set; } = "";
        public string FullName { get; set; } = "";
        public string DeviceToken { get; set; } = "";
        public string? Platform { get; set; }
    }
}
