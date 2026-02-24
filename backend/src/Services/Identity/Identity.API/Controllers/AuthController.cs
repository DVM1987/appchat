using Identity.Application.Features.Auth;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Identity.API.Controllers
{
    [ApiController]
    [Route("api/v1/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IMediator _mediator;

        public AuthController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterUserCommand command)
        {
            var userId = await _mediator.Send(command);
            return CreatedAtAction(nameof(Register), new { id = userId }, new { UserId = userId });
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginCommand command)
        {
            try
            {
                var response = await _mediator.Send(command);
                return Ok(response);
            }
            catch (Exception ex) when (ex.Message == "Invalid credentials")
            {
                return Unauthorized(new { message = "Invalid email or password" });
            }
            catch (Exception ex)
            {
                 Console.WriteLine($"[Login] Error: {ex.Message}");
                 return StatusCode(500, new { message = "Internal Server Error" });
            }
        }

        // ─── Phone OTP Endpoints ─────────────────────────────────

        [HttpPost("send-otp")]
        public async Task<IActionResult> SendOtp([FromBody] SendOtpCommand command)
        {
            try
            {
                var response = await _mediator.Send(command);
                return Ok(response);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[SendOtp] Error: {ex.Message}");
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpCommand command)
        {
            try
            {
                var response = await _mediator.Send(command);
                return Ok(response);
            }
            catch (Exception ex) when (ex.Message.Contains("Invalid or expired OTP"))
            {
                return Unauthorized(new { message = "Mã OTP không hợp lệ hoặc đã hết hạn" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[VerifyOtp] Error: {ex.Message}");
                return StatusCode(500, new { message = "Internal Server Error" });
            }
        }

        [HttpPost("refresh")]
        public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenCommand command)
        {
            try
            {
                var response = await _mediator.Send(command);
                return Ok(response);
            }
            catch (Exception ex) when (ex.Message.Contains("Invalid") || ex.Message.Contains("expired"))
            {
                return Unauthorized(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[RefreshToken] Error: {ex.Message}");
                return StatusCode(500, new { message = "Internal Server Error" });
            }
        }
    }
}
