using Identity.API.Extensions;
using Microsoft.EntityFrameworkCore;
using MassTransit;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Application Services (MediatR)
builder.Services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(typeof(Identity.Application.Features.Auth.RegisterUserCommand).Assembly));

// Infrastructure Services (EF Core)
builder.Services.AddDbContext<Identity.Infrastructure.Persistence.IdentityDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Dependency Injection
builder.Services.AddScoped<Identity.Application.Common.Interfaces.ITokenService, Identity.Infrastructure.Services.TokenService>();
builder.Services.AddScoped<Identity.Application.Common.Interfaces.IUserRepository, Identity.Infrastructure.Repositories.UserRepository>();
builder.Services.AddScoped<BuildingBlocks.Core.IUnitOfWork, Identity.Infrastructure.Services.UnitOfWork>();

// UserServiceClient for auto profile creation
builder.Services.AddHttpClient<Identity.Application.Common.Interfaces.IUserServiceClient, Identity.Infrastructure.Services.UserServiceClient>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration["UserServiceUrl"] ?? "http://user_service:8080");
    client.Timeout = TimeSpan.FromSeconds(30);
});

// MassTransit - TEMPORARILY DISABLED due to version conflict issue
// TODO: Re-enable after resolving MassTransit dependency conflicts
// builder.Services.AddMassTransit(x =>
// {
//     x.UsingRabbitMq((context, cfg) =>
//     {
//         cfg.Host(builder.Configuration["EventBusSettings:HostAddress"]);
//     });
// });

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Apply migrations
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var context = services.GetRequiredService<Identity.Infrastructure.Persistence.IdentityDbContext>();
        // Using EnsureCreated as there are no migrations yet
        context.Database.EnsureCreated();
    }
    catch (Exception ex)
    {
        var logger = services.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "An error occurred while initializing the database.");
    }
}

app.UseAuthorization();

app.MapControllers();

app.Run();
