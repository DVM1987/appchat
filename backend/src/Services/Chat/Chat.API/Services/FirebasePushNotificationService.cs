using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;

namespace Chat.API.Services
{
    /// <summary>
    /// Service for sending push notifications via Firebase Cloud Messaging (FCM).
    /// 
    /// Setup:
    ///   1. Create Firebase project at https://console.firebase.google.com
    ///   2. Go to Project Settings → Service accounts → Generate new private key
    ///   3. Save the JSON file as "firebase-admin-sdk.json" in Chat.API root
    ///   4. Or set environment variable GOOGLE_APPLICATION_CREDENTIALS=/path/to/firebase-admin-sdk.json
    /// </summary>
    public interface IPushNotificationService
    {
        Task SendToDeviceAsync(string deviceToken, string title, string body, Dictionary<string, string>? data = null, int badgeCount = 1);
        Task SendToMultipleAsync(List<string> deviceTokens, string title, string body, Dictionary<string, string>? data = null, int badgeCount = 1);
    }

    public class FirebasePushNotificationService : IPushNotificationService
    {
        private readonly ILogger<FirebasePushNotificationService> _logger;
        private readonly bool _isInitialized;

        public FirebasePushNotificationService(ILogger<FirebasePushNotificationService> logger, IConfiguration configuration)
        {
            _logger = logger;

            // Initialize Firebase Admin SDK
            if (FirebaseApp.DefaultInstance == null)
            {
                try
                {
                    var credentialPath = configuration["Firebase:CredentialPath"];

                    if (!string.IsNullOrEmpty(credentialPath) && File.Exists(credentialPath))
                    {
                        FirebaseApp.Create(new AppOptions
                        {
                            Credential = GoogleCredential.FromFile(credentialPath)
                        });
                        _isInitialized = true;
                        Console.WriteLine($"[FCM] Firebase initialized with credential file: {credentialPath}");
                        _logger.LogInformation("[FCM] Firebase initialized with credential file: {Path}", credentialPath);
                    }
                    else
                    {
                        // Try environment variable GOOGLE_APPLICATION_CREDENTIALS
                        var envPath = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS");
                        if (!string.IsNullOrEmpty(envPath) && File.Exists(envPath))
                        {
                            FirebaseApp.Create(new AppOptions
                            {
                                Credential = GoogleCredential.FromFile(envPath)
                            });
                            _isInitialized = true;
                            Console.WriteLine("[FCM] Firebase initialized from GOOGLE_APPLICATION_CREDENTIALS");
                            _logger.LogInformation("[FCM] Firebase initialized from GOOGLE_APPLICATION_CREDENTIALS");
                        }
                        else
                        {
                            Console.WriteLine($"[FCM] Firebase NOT initialized — credentialPath={credentialPath}, envPath={envPath}");
                            _logger.LogWarning("[FCM] Firebase NOT initialized — no credential file found. Push notifications disabled.");
                            _isInitialized = false;
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "[FCM] Failed to initialize Firebase");
                    _isInitialized = false;
                }
            }
            else
            {
                _isInitialized = true;
            }
        }

        public async Task SendToDeviceAsync(string deviceToken, string title, string body, Dictionary<string, string>? data = null, int badgeCount = 1)
        {
            if (!_isInitialized)
            {
                Console.WriteLine("[FCM] Firebase not initialized, skipping push notification");
                _logger.LogWarning("[FCM] Firebase not initialized, skipping push notification");
                return;
            }

            try
            {
                var message = new Message
                {
                    Token = deviceToken,
                    Notification = new Notification
                    {
                        Title = title,
                        Body = body,
                    },
                    Data = data,
                    Android = new AndroidConfig
                    {
                        Priority = Priority.High,
                        Notification = new AndroidNotification
                        {
                            Sound = "default",
                            ChannelId = "appchat_messages",
                        }
                    },
                    Apns = new ApnsConfig
                    {
                        Aps = new Aps
                        {
                            Alert = new ApsAlert
                            {
                                Title = title,
                                Body = body,
                            },
                            Sound = "default",
                            Badge = badgeCount,
                        }
                    }
                };

                Console.WriteLine($"[FCM] Sending push to token: {deviceToken.Substring(0, Math.Min(20, deviceToken.Length))}...");
                var result = await FirebaseMessaging.DefaultInstance.SendAsync(message);
                Console.WriteLine($"[FCM] Push sent successfully: {result}");
                _logger.LogInformation("[FCM] Push sent successfully: {MessageId}", result);
            }
            catch (FirebaseMessagingException ex) when (ex.MessagingErrorCode == MessagingErrorCode.Unregistered)
            {
                _logger.LogWarning("[FCM] Device token unregistered: {Token}", deviceToken.Substring(0, 20));
                // TODO: Remove token from user profile
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[FCM] ERROR sending push: {ex.Message}");
                _logger.LogError(ex, "[FCM] Failed to send push notification to {Token}", deviceToken.Substring(0, Math.Min(20, deviceToken.Length)));
            }
        }

        public async Task SendToMultipleAsync(List<string> deviceTokens, string title, string body, Dictionary<string, string>? data = null, int badgeCount = 1)
        {
            Console.WriteLine($"[FCM] SendToMultipleAsync called with {deviceTokens.Count} tokens, initialized={_isInitialized}");
            if (!_isInitialized || deviceTokens.Count == 0) return;

            var tasks = deviceTokens.Select(token => SendToDeviceAsync(token, title, body, data, badgeCount));
            await Task.WhenAll(tasks);
        }
    }
}
