#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/Services/Chat/Chat.API/Chat.API.csproj", "src/Services/Chat/Chat.API/"]
COPY ["src/Services/Chat/Chat.Application/Chat.Application.csproj", "src/Services/Chat/Chat.Application/"]
COPY ["src/Services/Chat/Chat.Domain/Chat.Domain.csproj", "src/Services/Chat/Chat.Domain/"]
COPY ["src/Services/Chat/Chat.Infrastructure/Chat.Infrastructure.csproj", "src/Services/Chat/Chat.Infrastructure/"]
COPY ["src/BuildingBlocks/BuildingBlocks.Core/BuildingBlocks.Core.csproj", "src/BuildingBlocks/BuildingBlocks.Core/"]
COPY ["src/BuildingBlocks/BuildingBlocks.CQRS/BuildingBlocks.CQRS.csproj", "src/BuildingBlocks/BuildingBlocks.CQRS/"]
RUN dotnet restore "src/Services/Chat/Chat.API/Chat.API.csproj"
COPY . .
WORKDIR "/src/src/Services/Chat/Chat.API"
RUN dotnet build "Chat.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Chat.API.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Chat.API.dll"]
