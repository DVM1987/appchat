FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/Services/Presence/Presence.API/Presence.API.csproj", "src/Services/Presence/Presence.API/"]
COPY ["src/Services/Presence/Presence.Infrastructure/Presence.Infrastructure.csproj", "src/Services/Presence/Presence.Infrastructure/"]
COPY ["src/Services/Presence/Presence.Domain/Presence.Domain.csproj", "src/Services/Presence/Presence.Domain/"]
COPY ["src/BuildingBlocks/BuildingBlocks.Core/BuildingBlocks.Core.csproj", "src/BuildingBlocks/BuildingBlocks.Core/"]
RUN dotnet restore "src/Services/Presence/Presence.API/Presence.API.csproj"
COPY . .
WORKDIR "/src/src/Services/Presence/Presence.API"
RUN dotnet build "Presence.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Presence.API.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Presence.API.dll"]
