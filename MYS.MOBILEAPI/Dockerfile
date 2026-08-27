# Build
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY src/AMSEL.MobileApi/AMSEL.MobileApi.csproj AMSEL.MobileApi/
RUN dotnet restore AMSEL.MobileApi/AMSEL.MobileApi.csproj

COPY src/AMSEL.MobileApi/ AMSEL.MobileApi/
RUN dotnet publish AMSEL.MobileApi/AMSEL.MobileApi.csproj -c Release -o /app --no-restore

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /app .

ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
# Disables the default appsettings.json FileSystemWatcher (config never
# changes without a redeploy anyway) — without this, WebApplication
# .CreateBuilder crashes on hosts with a low inotify limit (e.g. Render's
# shared container infra), since the watcher can't be created.
ENV DOTNET_hostBuilder__reloadConfigOnChange=false
EXPOSE 8080

ENTRYPOINT ["dotnet", "AMSEL.MobileApi.dll"]
