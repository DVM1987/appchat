using Microsoft.AspNetCore.Mvc;

namespace User.API.Controllers
{
    [ApiController]
    [Route("api/v1/[controller]")]
    public class MediaController : ControllerBase
    {
        private readonly IWebHostEnvironment _environment;
        private readonly ILogger<MediaController> _logger;

        public MediaController(IWebHostEnvironment environment, ILogger<MediaController> logger)
        {
            _environment = environment;
            _logger = logger;
        }

        [HttpPost("upload")]
        public async Task<IActionResult> UploadFile(IFormFile file)
        {
            if (file == null || file.Length == 0)
                return BadRequest("No file uploaded.");

            try
            {
                // Ensure directory exists
                string webRootPath = _environment.WebRootPath ?? Path.Combine(_environment.ContentRootPath, "wwwroot");
                var uploadsFolder = Path.Combine(webRootPath, "uploads");
                
                if (!Directory.Exists(uploadsFolder))
                    Directory.CreateDirectory(uploadsFolder);

                // Create unique filename
                var uniqueFileName = Guid.NewGuid().ToString() + "_" + file.FileName;
                var filePath = Path.Combine(uploadsFolder, uniqueFileName);

                using (var fileStream = new FileStream(filePath, FileMode.Create))
                {
                    await file.CopyToAsync(fileStream);
                }

                // Return relative URL
                var fileUrl = $"/uploads/{uniqueFileName}";
                return Ok(new { url = fileUrl });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error uploading file");
                return StatusCode(500, "Internal server error");
            }
        }
    }
}
