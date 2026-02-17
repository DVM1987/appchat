using User.Infrastructure;
using User.Application.Features.Profiles;
using User.Application.IntegrationEvents;
using MassTransit;
using System.Reflection;
using Microsoft.EntityFrameworkCore;
using User.API.Hubs;
using System.IdentityModel.Tokens.Jwt;

// Clear default claim mapping to keep 'sub', 'name', etc. as is
JwtSecurityTokenHandler.DefaultInboundClaimTypeMap.Clear();

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// SignalR
builder.Services.AddSignalR();

// Application Services (MediatR)
builder.Services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(typeof(CreateUserProfileCommand).Assembly));

// Infrastructure Services (EF Core, Repos)
builder.Services.AddUserInfrastructure(builder.Configuration);

// MassTransit
builder.Services.AddMassTransit(x =>
{
    x.AddConsumer<UserRegisteredConsumer>();

    x.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host(builder.Configuration["EventBusSettings:HostAddress"]);

        cfg.ReceiveEndpoint("user-service-user-registered", e =>
        {
            e.ConfigureConsumer<UserRegisteredConsumer>(context);
        });
    });
});

// Add Authentication
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = builder.Configuration["Jwt:Issuer"];
        options.TokenValidationParameters = new Microsoft.IdentityModel.Tokens.TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new Microsoft.IdentityModel.Tokens.SymmetricSecurityKey(
                System.Text.Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!)),
            NameClaimType = "sub" // Use 'sub' for User.Identity.Name / Context.UserIdentifier
        };
        // For development/container to container communication (http)
        options.RequireHttpsMetadata = false; 

        options.Events = new Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) &&
                    (path.StartsWithSegments("/userHub")))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

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
        var context = services.GetRequiredService<User.Infrastructure.Persistence.UserDbContext>();
        if (context.Database.GetPendingMigrations().Any())
        {
            context.Database.Migrate();
        }
    }
    catch (Exception ex)
    {
        var logger = services.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "An error occurred while migrating the database.");
    }
}

// Enable static files to serve uploaded images (e.g. from wwwroot/uploads)
app.UseStaticFiles();

// app.UseHttpsRedirection(); // Disable for internal container comms if not needed or configured

// Must serve Authentication before Authorization
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<UserHub>("/userHub");

app.Run();
