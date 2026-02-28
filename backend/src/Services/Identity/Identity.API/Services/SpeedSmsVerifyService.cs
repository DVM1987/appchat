using Identity.Application.Common.Interfaces;
using Microsoft.Extensions.Caching.Memory;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Identity.API.Services
{
    /// <summary>
    /// OTP SMS service using SpeedSMS.vn (Vietnamese SMS provider).
    /// Self-managed OTP: generate → cache (5 min) → send SMS via SpeedSMS REST API → verify from cache.
    /// 
    /// API docs: https://speedsms.vn/sms-api-service/
    /// Type 2 = gửi từ đầu số ngẫu nhiên (không cần Brand Name)
    /// </summary>
    public class SpeedSmsVerifyService : ISmsVerifyService
    {
        private readonly string _accessToken;
        private readonly IMemoryCache _cache;
        private readonly HttpClient _httpClient;

        private const string SPEEDSMS_API_URL = "https://api.speedsms.vn/index.php/sms/send";
        private static readonly TimeSpan OTP_EXPIRY = TimeSpan.FromMinutes(5);

        public SpeedSmsVerifyService(IConfiguration config, IMemoryCache cache, HttpClient httpClient)
        {
            _accessToken = config["SpeedSms:AccessToken"]
                ?? throw new InvalidOperationException("SpeedSms:AccessToken is missing");
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

            Console.WriteLine($"[SpeedSMS] Generated OTP for {phoneNumber}: {otp}");

            // 3. Send SMS via SpeedSMS REST API
            try
            {
                var localPhone = FormatPhone(phoneNumber);
                var smsContent = $"Ma xac thuc MChat cua ban la: {otp}. Ma co hieu luc trong 5 phut.";

                // SpeedSMS uses HTTP Basic Auth: token as username
                var authBytes = Encoding.ASCII.GetBytes($"{_accessToken}:x");
                _httpClient.DefaultRequestHeaders.Authorization =
                    new AuthenticationHeaderValue("Basic", Convert.ToBase64String(authBytes));

                var payload = new
                {
                    to = localPhone,
                    content = smsContent,
                    sms_type = 2,   // Type 2 = đầu số ngẫu nhiên (không cần Brand Name)
                    sender = ""     // Không cần sender cho type 2
                };

                Console.WriteLine($"[SpeedSMS] Sending SMS to {localPhone}");

                var jsonContent = new StringContent(
                    JsonSerializer.Serialize(payload),
                    Encoding.UTF8,
                    "application/json");

                var response = await _httpClient.PostAsync(SPEEDSMS_API_URL, jsonContent);
                var responseBody = await response.Content.ReadAsStringAsync();

                Console.WriteLine($"[SpeedSMS] Response: {response.StatusCode} - {responseBody}");

                var result = JsonSerializer.Deserialize<SpeedSmsResponse>(responseBody);

                if (result?.status == "error")
                {
                    Console.WriteLine($"[SpeedSMS] ❌ Error: code={result.code}, msg={result.message}");
                    throw new Exception($"SpeedSMS error ({result.code}): {result.message}");
                }

                Console.WriteLine($"[SpeedSMS] ✅ OTP sent successfully to {localPhone}");
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[SpeedSMS] ❌ Failed to send OTP to {phoneNumber}: {ex.Message}");
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
                    Console.WriteLine($"[SpeedSMS] ✅ OTP verified for {phoneNumber}");
                    return Task.FromResult(true);
                }
                else
                {
                    Console.WriteLine($"[SpeedSMS] ❌ OTP mismatch for {phoneNumber}");
                }
            }
            else
            {
                Console.WriteLine($"[SpeedSMS] ❌ OTP expired or not found for {phoneNumber}");
            }

            return Task.FromResult(false);
        }

        // ════════════════════════════════════════
        // HELPERS
        // ════════════════════════════════════════

        private static string GenerateOtp()
        {
            var bytes = RandomNumberGenerator.GetBytes(4);
            var num = BitConverter.ToUInt32(bytes, 0) % 1000000;
            return num.ToString("D6");
        }

        private static string GetCacheKey(string phoneNumber)
            => $"otp:{phoneNumber.Replace("+", "")}";

        /// <summary>
        /// Convert E.164 (+84961998923) to SpeedSMS format (84961998923).
        /// </summary>
        private static string FormatPhone(string phone)
        {
            if (phone.StartsWith("+"))
                return phone[1..];
            return phone;
        }
    }

    // SpeedSMS API response model
    internal class SpeedSmsResponse
    {
        public string? status { get; set; }
        public string? code { get; set; }
        public string? message { get; set; }
        public SpeedSmsData? data { get; set; }
    }

    internal class SpeedSmsData
    {
        public int tranId { get; set; }
        public int totalSMS { get; set; }
        public int totalPrice { get; set; }
    }
}
