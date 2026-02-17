using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Chat.API.Controllers
{
    [ApiController]
    [Authorize]
    [Route("api/v1/[controller]")]
    public class FilesController : ControllerBase
    {
        private readonly IWebHostEnvironment _env;

        public FilesController(IWebHostEnvironment env)
        {
            _env = env;
        }

        /// <summary>
        /// Upload one or multiple files. Returns a list of URLs.
        /// </summary>
        [HttpPost("upload")]
        [RequestSizeLimit(50_000_000)] // 50 MB max total
        public async Task<IActionResult> Upload([FromForm] List<IFormFile> files)
        {
            if (files == null || files.Count == 0)
            {
                return BadRequest("No files provided");
            }

            var uploadsDir = Path.Combine(_env.ContentRootPath, "wwwroot", "chat-uploads");
            Directory.CreateDirectory(uploadsDir);

            var urls = new List<string>();

            foreach (var file in files)
            {
                if (file.Length == 0) continue;

                // Validate file type (images + audio)
                var allowedTypes = new[] { 
                    "image/jpeg", "image/png", "image/gif", "image/webp", "image/heic", "image/heif",
                    "audio/mp4", "audio/m4a", "audio/aac", "audio/mpeg", "audio/wav", "audio/ogg", "audio/opus",
                    "audio/x-m4a", "audio/mp4a-latm"
                };
                var allowedExtensions = new[] { 
                    ".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".heif",
                    ".m4a", ".aac", ".mp3", ".wav", ".ogg", ".opus"
                };
                var fileExt = Path.GetExtension(file.FileName)?.ToLower() ?? "";
                
                if (!allowedTypes.Contains(file.ContentType.ToLower()) && !allowedExtensions.Contains(fileExt))
                {
                    continue; // Skip unsupported files
                }

                // Generate unique filename
                var ext = Path.GetExtension(file.FileName);
                var uniqueName = $"{Guid.NewGuid()}{ext}";
                var filePath = Path.Combine(uploadsDir, uniqueName);

                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await file.CopyToAsync(stream);
                }

                // Build URL relative to the server
                var url = $"/chat-uploads/{uniqueName}";
                urls.Add(url);
            }

            if (urls.Count == 0)
            {
                return BadRequest("No valid image files uploaded");
            }

            return Ok(new { urls });
        }
    }
}
