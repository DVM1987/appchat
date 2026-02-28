using Identity.Application.Common.Interfaces;
using Microsoft.Extensions.Caching.Memory;
using System.Net.Http.Json;
using System.Security.Cryptography;

namespace Identity.API.Services
{
    /// <summary>
    /// OTP SMS service using eSMS.vn (Vietnamese SMS provider).
    /// Self-managed OTP: generate → cache (5 min) → send SMS → verify from cache.
    /// 
    /// eSMS.vn API docs: https://developers.esms.vn
    /// </summary>
    public class EsmsVerifyService : ISmsVerifyService
    {
        private readonly string _apiKey;
        private readonly string _secretKey;
        private readonly string _brandName;
        private readonly IMemoryCache _cache;
        private readonly HttpClient _httpClient;

        private const string ESMS_API_URL = "https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json/";
        private static readonly TimeSpan OTP_EXPIRY = TimeSpan.FromMinutes(5);

        public EsmsVerifyService(IConfiguration config, IMemoryCache cache, HttpClient httpClient)
        {
            _apiKey = config["Esms:ApiKey"]
                ?? throw new InvalidOperationException("Esms:ApiKey is missing");
            _secretKey = config["Esms:SecretKey"]
                ?? throw new InvalidOperationException("Esms:SecretKey is missing");
            _brandName = config["Esms:BrandName"] ?? "";
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

            Console.WriteLine($"[eSMS] Generated OTP for {phoneNumber}: {otp}");

            // 3. Send SMS via eSMS.vn API
            try
            {
                // Format phone for Vietnam: remove +84 prefix, use 0 prefix
                var localPhone = FormatPhoneForEsms(phoneNumber);

                var smsContent = $"Ma xac thuc MChat cua ban la: {otp}. Ma co hieu luc trong 5 phut.";

                var payload = new
                {
                    ApiKey = _apiKey,
                    Content = smsContent,
                    Phone = localPhone,
                    SecretKey = _secretKey,
                    IsUnicode = 0,      // ASCII (no diacritics — cheaper)
                    Brandname = _brandName,
                    SmsType = 2,        // Type 2 = OTP/Customer Care
                    Sandbox = 0         // 0 = production, 1 = sandbox (no actual SMS sent)
                };

                Console.WriteLine($"[eSMS] Sending SMS to {localPhone}: {smsContent}");

                var response = await _httpClient.PostAsJsonAsync(ESMS_API_URL, payload);
                var responseBody = await response.Content.ReadAsStringAsync();

                Console.WriteLine($"[eSMS] Response: {response.StatusCode} - {responseBody}");

                if (!response.IsSuccessStatusCode)
                {
                    throw new Exception($"eSMS API returned {response.StatusCode}: {responseBody}");
                }

                // Parse eSMS response — CodeResult: "100" means success
                var result = System.Text.Json.JsonSerializer.Deserialize<EsmsResponse>(responseBody);
                if (result?.CodeResult != "100")
                {
                    Console.WriteLine($"[eSMS] Send failed: Code={result?.CodeResult}, Error={result?.ErrorMessage}");
                    throw new Exception($"eSMS error: {result?.ErrorMessage ?? responseBody}");
                }

                Console.WriteLine($"[eSMS] ✅ OTP sent successfully to {localPhone}, SMSID: {result.SMSID}");
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[eSMS] ❌ Failed to send OTP to {phoneNumber}: {ex.Message}");
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
                    // OTP valid — remove from cache (one-time use)
                    _cache.Remove(cacheKey);
                    Console.WriteLine($"[eSMS] ✅ OTP verified for {phoneNumber}");
                    return Task.FromResult(true);
                }
                else
                {
                    Console.WriteLine($"[eSMS] ❌ OTP mismatch for {phoneNumber}: expected={storedOtp}, got={code}");
                }
            }
            else
            {
                Console.WriteLine($"[eSMS] ❌ OTP expired or not found for {phoneNumber}");
            }

            return Task.FromResult(false);
        }

        // ════════════════════════════════════════
        // HELPERS
        // ════════════════════════════════════════

        private static string GenerateOtp()
        {
            // Cryptographically secure 6-digit OTP
            var bytes = RandomNumberGenerator.GetBytes(4);
            var num = BitConverter.ToUInt32(bytes, 0) % 1000000;
            return num.ToString("D6");
        }

        private static string GetCacheKey(string phoneNumber)
            => $"otp:{phoneNumber.Replace("+", "")}";

        /// <summary>
        /// Convert E.164 (+84961998923) to local format (0961998923) for eSMS.
        /// </summary>
        private static string FormatPhoneForEsms(string phone)
        {
            if (phone.StartsWith("+84"))
                return "0" + phone[3..];
            if (phone.StartsWith("84"))
                return "0" + phone[2..];
            return phone;
        }
    }

    // eSMS.vn API response model
    internal class EsmsResponse
    {
        public string? CodeResult { get; set; }
        public string? ErrorMessage { get; set; }
        public string? SMSID { get; set; }
    }
}
