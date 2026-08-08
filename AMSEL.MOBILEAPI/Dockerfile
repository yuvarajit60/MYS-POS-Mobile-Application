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
EXPOSE 8080

ENTRYPOINT ["dotnet", "AMSEL.MobileApi.dll"]
