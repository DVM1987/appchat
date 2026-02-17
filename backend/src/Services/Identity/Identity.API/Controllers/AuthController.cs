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
    }
}
