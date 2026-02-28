using Identity.API.Extensions;
using Identity.API.Services;
using Microsoft.EntityFrameworkCore;
using MassTransit;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;

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
builder.Services.AddMemoryCache();

// Firebase Admin SDK initialization
var firebaseCredPath = builder.Configuration["Firebase:CredentialPath"] ?? "firebase-admin-sdk.json";
if (File.Exists(firebaseCredPath))
{
    if (FirebaseApp.DefaultInstance == null)
    {
        FirebaseApp.Create(new AppOptions
        {
            Credential = GoogleCredential.FromFile(firebaseCredPath),
        });
    }
    Console.WriteLine($"[Firebase] Admin SDK initialized from {firebaseCredPath}");
}
else
{
    Console.WriteLine($"[Firebase] WARNING: credential file not found at {firebaseCredPath}");
}

// Firebase Auth Service (replaces SMS verify service)
builder.Services.AddSingleton<Identity.Application.Common.Interfaces.IFirebaseAuthService, FirebaseAuthService>();

// Keep ISmsVerifyService as no-op for backward compatibility (Apple test account uses old endpoints)
builder.Services.AddSingleton<Identity.Application.Common.Interfaces.ISmsVerifyService, NoOpSmsVerifyService>();

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

// Apply migrations / ensure schema is up to date
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var context = services.GetRequiredService<Identity.Infrastructure.Persistence.IdentityDbContext>();
        
        // Create database if it doesn't exist
        context.Database.EnsureCreated();
        
        // Apply schema updates for phone auth (safe to run multiple times)
        var conn = context.Database.GetDbConnection();
        await conn.OpenAsync();
        using var cmd = conn.CreateCommand();
        
        // Add PhoneNumber column if not exists
        cmd.CommandText = @"
            DO $$ BEGIN
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_name='Users' AND column_name='PhoneNumber') THEN
                    ALTER TABLE ""Users"" ADD COLUMN ""PhoneNumber"" VARCHAR(20) NULL;
                    CREATE UNIQUE INDEX IF NOT EXISTS ""IX_Users_PhoneNumber"" ON ""Users"" (""PhoneNumber"") WHERE ""PhoneNumber"" IS NOT NULL;
                END IF;
            END $$;
            
            ALTER TABLE ""Users"" ALTER COLUMN ""Email"" DROP NOT NULL;
            ALTER TABLE ""Users"" ALTER COLUMN ""PasswordHash"" DROP NOT NULL;
            
            CREATE TABLE IF NOT EXISTS ""OtpEntries"" (
                ""Id"" UUID NOT NULL PRIMARY KEY,
                ""PhoneNumber"" VARCHAR(20) NOT NULL,
                ""Code"" VARCHAR(10) NOT NULL,
                ""ExpiresAt"" TIMESTAMP WITH TIME ZONE NOT NULL,
                ""IsUsed"" BOOLEAN NOT NULL DEFAULT FALSE,
                ""CreatedAt"" TIMESTAMP WITH TIME ZONE NOT NULL
            );
            CREATE INDEX IF NOT EXISTS ""IX_OtpEntries_PhoneNumber"" ON ""OtpEntries"" (""PhoneNumber"");

            CREATE TABLE IF NOT EXISTS ""RefreshTokens"" (
                ""Id"" UUID NOT NULL PRIMARY KEY,
                ""UserId"" UUID NOT NULL,
                ""Token"" VARCHAR(256) NOT NULL,
                ""ExpiresAt"" TIMESTAMP WITH TIME ZONE NOT NULL,
                ""CreatedAt"" TIMESTAMP WITH TIME ZONE NOT NULL,
                ""IsRevoked"" BOOLEAN NOT NULL DEFAULT FALSE
            );
            CREATE UNIQUE INDEX IF NOT EXISTS ""IX_RefreshTokens_Token"" ON ""RefreshTokens"" (""Token"");
            CREATE INDEX IF NOT EXISTS ""IX_RefreshTokens_UserId"" ON ""RefreshTokens"" (""UserId"");
        ";
        await cmd.ExecuteNonQueryAsync();
        
        Console.WriteLine("[DB] Schema migration for Phone Auth + RefreshTokens completed successfully.");
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
