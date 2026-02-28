using Identity.Application.Common.Interfaces;
using Microsoft.Extensions.Caching.Memory;
using System.IdentityModel.Tokens.Jwt;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace Identity.API.Services
{
    /// <summary>
    /// OTP SMS service using Stringee (Vietnamese SMS provider).
    /// Self-managed OTP: generate → cache (5 min) → send SMS via Stringee REST API → verify from cache.
    /// 
    /// API docs: https://developer.stringee.com/docs/stringee-sms-rest-api
    /// </summary>
    public class StringeeVerifyService : ISmsVerifyService
    {
        private readonly string _apiKeySid;
        private readonly string _apiKeySecret;
        private readonly string _brandName;
        private readonly IMemoryCache _cache;
        private readonly HttpClient _httpClient;

        private const string STRINGEE_SMS_URL = "https://api.stringee.com/v1/sms";
        private static readonly TimeSpan OTP_EXPIRY = TimeSpan.FromMinutes(5);

        public StringeeVerifyService(IConfiguration config, IMemoryCache cache, HttpClient httpClient)
        {
            _apiKeySid = config["Stringee:ApiKeySid"]
                ?? throw new InvalidOperationException("Stringee:ApiKeySid is missing");
            _apiKeySecret = config["Stringee:ApiKeySecret"]
                ?? throw new InvalidOperationException("Stringee:ApiKeySecret is missing");
            _brandName = config["Stringee:BrandName"] ?? "MChat";
            _cache = cache;
            _httpClient = httpClient;
        }

        public async Task<bool> SendOtpAsync(string phoneNumber)
        {
            // 1. Generate 6-digit OTP
            var otp = GenerateOtp();

            // 2. Store in cache with 5 min expiry
            var cacheKey = GetCacheKey(phoneNumber);
            _cache.Set(cacheKey, otp, OTP_EXPIRY);

            Console.WriteLine($"[Stringee] Generated OTP for {phoneNumber}: {otp}");

            // 3. Send SMS via Stringee REST API
            try
            {
                var localPhone = FormatPhoneForStringee(phoneNumber);
                var smsContent = $"Ma xac thuc MChat cua ban la: {otp}. Ma co hieu luc trong 5 phut.";

                // Generate JWT for Stringee auth
                var jwt = GenerateStringeeJwt();

                var payload = new
                {
                    sms = new[]
                    {
                        new
                        {
                            from = _brandName,
                            to = localPhone,
                            text = smsContent
                        }
                    }
                };

                var request = new HttpRequestMessage(HttpMethod.Post, STRINGEE_SMS_URL);
                request.Headers.Add("X-STRINGEE-AUTH", jwt);
                request.Content = JsonContent.Create(payload);

                Console.WriteLine($"[Stringee] Sending SMS to {localPhone}: {smsContent}");

                var response = await _httpClient.SendAsync(request);
                var responseBody = await response.Content.ReadAsStringAsync();

                Console.WriteLine($"[Stringee] Response: {response.StatusCode} - {responseBody}");

                if (!response.IsSuccessStatusCode)
                {
                    throw new Exception($"Stringee API returned {response.StatusCode}: {responseBody}");
                }

                // Parse response: r=0 means success
                var result = System.Text.Json.JsonSerializer.Deserialize<StringeeResponse>(responseBody);
                if (result?.result != null && result.result.Length > 0 && result.result[0].r != 0)
                {
                    Console.WriteLine($"[Stringee] Send failed: r={result.result[0].r}, msg={result.result[0].msg}");
                    throw new Exception($"Stringee error: {result.result[0].msg}");
                }

                Console.WriteLine($"[Stringee] ✅ OTP sent successfully to {localPhone}");
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Stringee] ❌ Failed to send OTP to {phoneNumber}: {ex.Message}");
                throw new Exception($"Không thể gửi mã OTP: {ex.Message}");
            }
        }

        public Task<bool> VerifyOtpAsync(string phoneNumber, string code)
        {
            var cacheKey = GetCacheKey(phoneNumber);

            if (_cache.TryGetValue(cacheKey, out string? storedOtp))
            {
                if (storedOtp == code)
                {
                    _cache.Remove(cacheKey);
                    Console.WriteLine($"[Stringee] ✅ OTP verified for {phoneNumber}");
                    return Task.FromResult(true);
                }
                else
                {
                    Console.WriteLine($"[Stringee] ❌ OTP mismatch for {phoneNumber}");
                }
            }
            else
            {
                Console.WriteLine($"[Stringee] ❌ OTP expired or not found for {phoneNumber}");
            }

            return Task.FromResult(false);
        }

        // ════════════════════════════════════════
        // HELPERS
        // ════════════════════════════════════════

        private string GenerateStringeeJwt()
        {
            var now = DateTimeOffset.UtcNow;
            var exp = now.AddHours(1);

            var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_apiKeySecret));
            var credentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);

            var header = new JwtHeader(credentials);
            header["cty"] = "stringee-api;v=1";

            var payload = new JwtPayload
            {
                { "jti", $"{_apiKeySid}-{now.ToUnixTimeSeconds()}" },
                { "iss", _apiKeySid },
                { "exp", exp.ToUnixTimeSeconds() },
                { "rest_api", true }
            };

            var token = new JwtSecurityToken(header, payload);
            return new JwtSecurityTokenHandler().WriteToken(token);
        }

        private static string GenerateOtp()
        {
            var bytes = RandomNumberGenerator.GetBytes(4);
            var num = BitConverter.ToUInt32(bytes, 0) % 1000000;
            return num.ToString("D6");
        }

        private static string GetCacheKey(string phoneNumber)
            => $"otp:{phoneNumber.Replace("+", "")}";

        /// <summary>
        /// Convert E.164 (+84961998923) to Stringee format (84961998923).
        /// </summary>
        private static string FormatPhoneForStringee(string phone)
        {
            if (phone.StartsWith("+"))
                return phone[1..];
            return phone;
        }
    }

    // Stringee SMS API response models
    internal class StringeeResponse
    {
        public int smsSent { get; set; }
        public StringeeSmsResult[]? result { get; set; }
    }

    internal class StringeeSmsResult
    {
        public string? price { get; set; }
        public int smsType { get; set; }
        public int r { get; set; }
        public string? msg { get; set; }
    }
}
