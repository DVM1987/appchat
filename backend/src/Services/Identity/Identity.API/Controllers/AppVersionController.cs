using Microsoft.AspNetCore.Mvc;

namespace Identity.API.Controllers;

/// <summary>
/// Public endpoint for mobile apps to check if they need to update.
/// No authentication required.
/// </summary>
[ApiController]
[Route("api/v1/[controller]")]
public class AppVersionController : ControllerBase
{
    // These could also come from appsettings.json or a database.
    // For now, hardcoded for simplicity — just redeploy to change.
    private const string LatestVersion = "1.0.0";
    private const string MinVersion = "1.0.0";
    private const string AndroidStoreUrl = "https://play.google.com/store/apps/details?id=com.appchat.mobile";
    private const string IosStoreUrl = "https://apps.apple.com/app/mchat/id0000000000"; // Replace with real ID
    private const string ReleaseNotes = "Phiên bản đầu tiên của MChat!";

    /// <summary>
    /// Check the latest app version and whether the client must update.
    /// GET /api/v1/appversion/check?platform=ios&currentVersion=1.0.0
    /// </summary>
    [HttpGet("check")]
    public IActionResult Check(
        [FromQuery] string platform = "ios",
        [FromQuery] string currentVersion = "1.0.0")
    {
        var storeUrl = platform.ToLowerInvariant() == "android"
            ? AndroidStoreUrl
            : IosStoreUrl;

        var response = new
        {
            latestVersion = LatestVersion,
            minVersion = MinVersion,
            storeUrl,
            releaseNotes = ReleaseNotes,
            forceUpdate = CompareVersions(currentVersion, MinVersion) < 0,
            updateAvailable = CompareVersions(currentVersion, LatestVersion) < 0
        };

        return Ok(response);
    }

    /// <summary>
    /// Compare two semantic version strings (e.g. "1.2.3").
    /// Returns negative if a < b, 0 if equal, positive if a > b.
    /// </summary>
    private static int CompareVersions(string a, string b)
    {
        var partsA = a.Split('.').Select(int.Parse).ToArray();
        var partsB = b.Split('.').Select(int.Parse).ToArray();
        var len = Math.Max(partsA.Length, partsB.Length);

        for (var i = 0; i < len; i++)
        {
            var va = i < partsA.Length ? partsA[i] : 0;
            var vb = i < partsB.Length ? partsB[i] : 0;
            if (va != vb) return va.CompareTo(vb);
        }
        return 0;
    }
}
