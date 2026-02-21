using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Chat.API.Controllers
{
    [ApiController]
    [Route("api/v1/[controller]")]
    [Authorize]
    public class AgoraController : ControllerBase
    {
        private readonly IConfiguration _configuration;

        public AgoraController(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        /// <summary>
        /// Generate an Agora RTC token for a given channel name.
        /// The token is tied to the authenticated user's ID (from JWT sub claim).
        /// </summary>
        [HttpGet("token")]
        public IActionResult GetToken([FromQuery] string channelName)
        {
            if (string.IsNullOrWhiteSpace(channelName))
                return BadRequest(new { message = "channelName is required" });

            var userId = User.FindFirst("sub")?.Value
                      ?? User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            if (string.IsNullOrEmpty(userId))
                return Unauthorized(new { message = "User identity not found" });

            var appId = _configuration["Agora:AppId"] ?? "907e967d3be9444b9336adbd6bf6a6d6";
            var appCertificate = _configuration["Agora:AppCertificate"] ?? "";

            // Generate UID from userId hash (same algorithm as Flutter side)
            uint uid = (uint)(userId.GetHashCode() & 0x7FFFFFFF);
            if (uid == 0) uid = 1;

            // If no AppCertificate configured, return empty token (for testing mode)
            if (string.IsNullOrEmpty(appCertificate))
            {
                return Ok(new
                {
                    token = (string?)null,
                    uid = uid,
                    channelName = channelName,
                    appId = appId,
                    message = "No AppCertificate configured - using testing mode (no token required)"
                });
            }

            // Generate RTC token using Agora token builder
            var token = AgoraTokenBuilder.BuildToken(
                appId,
                appCertificate,
                channelName,
                uid,
                3600 // Token expires in 1 hour
            );

            return Ok(new
            {
                token = token,
                uid = uid,
                channelName = channelName,
                appId = appId
            });
        }
    }

    /// <summary>
    /// Agora RTC Token Builder
    /// Implements the Agora token generation algorithm.
    /// Reference: https://docs.agora.io/en/video-calling/develop/authentication-workflow
    /// </summary>
    public static class AgoraTokenBuilder
    {
        public static string BuildToken(
            string appId,
            string appCertificate,
            string channelName,
            uint uid,
            int expireTimeInSeconds)
        {
            var timestamp = (uint)DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var privilegeExpireTs = timestamp + (uint)expireTimeInSeconds;

            // Build token using HMAC
            var message = new AgoraAccessToken(appId, appCertificate, channelName, uid.ToString());
            message.AddPrivilege(Privileges.JoinChannel, privilegeExpireTs);
            message.AddPrivilege(Privileges.PublishAudioStream, privilegeExpireTs);
            message.AddPrivilege(Privileges.PublishVideoStream, privilegeExpireTs);
            message.AddPrivilege(Privileges.PublishDataStream, privilegeExpireTs);

            return message.Build();
        }
    }

    public enum Privileges : ushort
    {
        JoinChannel = 1,
        PublishAudioStream = 2,
        PublishVideoStream = 3,
        PublishDataStream = 4,
    }

    public class AgoraAccessToken
    {
        private readonly string _appId;
        private readonly string _appCertificate;
        private readonly string _channelName;
        private readonly string _uid;
        private readonly uint _ts;
        private readonly uint _salt;
        private readonly Dictionary<ushort, uint> _privileges = new();

        private const string Version = "006";

        public AgoraAccessToken(string appId, string appCertificate, string channelName, string uid)
        {
            _appId = appId;
            _appCertificate = appCertificate;
            _channelName = channelName;
            _uid = uid;
            _ts = (uint)DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            _salt = (uint)new Random().Next(1, 99999999);
        }

        public void AddPrivilege(Privileges privilege, uint expireTimestamp)
        {
            _privileges[(ushort)privilege] = expireTimestamp;
        }

        public string Build()
        {
            var msgBytes = PackContent();
            var signBytes = GenerateSignature(_appCertificate, _appId, _channelName, _uid, msgBytes);

            using var ms = new MemoryStream();
            using var writer = new BinaryWriter(ms);

            // Pack signature
            var signStr = Convert.ToBase64String(signBytes);
            PackString(writer, signStr);

            // Pack other fields
            PackUint32(writer, _ts);
            PackUint32(writer, _salt);

            // Pack message
            PackString(writer, Convert.ToBase64String(msgBytes));

            return Version + Convert.ToBase64String(ms.ToArray());
        }

        private byte[] PackContent()
        {
            using var ms = new MemoryStream();
            using var writer = new BinaryWriter(ms);

            // Pack privileges
            PackUint16(writer, (ushort)_privileges.Count);
            foreach (var kv in _privileges.OrderBy(x => x.Key))
            {
                PackUint16(writer, kv.Key);
                PackUint32(writer, kv.Value);
            }

            return ms.ToArray();
        }

        private static byte[] GenerateSignature(string appCertificate, string appId, string channelName, string uid, byte[] message)
        {
            using var ms = new MemoryStream();
            using var writer = new BinaryWriter(ms);
            PackString(writer, appId);
            PackString(writer, channelName);
            PackString(writer, uid);
            writer.Write(message);

            var val = ms.ToArray();

            using var hmac = new System.Security.Cryptography.HMACSHA256(System.Text.Encoding.UTF8.GetBytes(appCertificate));
            return hmac.ComputeHash(val);
        }

        private static void PackUint16(BinaryWriter writer, ushort value)
        {
            writer.Write(value);
        }

        private static void PackUint32(BinaryWriter writer, uint value)
        {
            writer.Write(value);
        }

        private static void PackString(BinaryWriter writer, string value)
        {
            var bytes = System.Text.Encoding.UTF8.GetBytes(value);
            PackUint16(writer, (ushort)bytes.Length);
            writer.Write(bytes);
        }
    }
}
