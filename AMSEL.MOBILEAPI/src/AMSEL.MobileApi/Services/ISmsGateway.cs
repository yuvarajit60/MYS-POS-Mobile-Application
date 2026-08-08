namespace AMSEL.MobileApi.Services;

public interface ISmsGateway
{
    Task SendAsync(string mobileNo, string message);
}

/// <summary>
/// Reuses the desktop app's existing SMS gateway account (same provider/URL pattern as
/// AMSEL.BOL.BOL.SENDSMS and AMSEL.WINAPP.MODULES.General), configured via the "Sms" section.
/// </summary>
public class SmsGateway : ISmsGateway
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<SmsGateway> _logger;

    public SmsGateway(HttpClient httpClient, IConfiguration configuration, ILogger<SmsGateway> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SendAsync(string mobileNo, string message)
    {
        var baseUrl = _configuration["Sms:BaseUrl"];
        var username = _configuration["Sms:Username"];
        var password = _configuration["Sms:Password"];
        var senderName = _configuration["Sms:SenderName"];

        if (string.IsNullOrWhiteSpace(baseUrl) || string.IsNullOrWhiteSpace(username))
        {
            _logger.LogWarning("SMS gateway is not configured; skipping send to {MobileNo}.", mobileNo);
            return;
        }

        var url = $"{baseUrl}?username={Uri.EscapeDataString(username)}&password={Uri.EscapeDataString(password ?? "")}" +
                  $"&mobile={Uri.EscapeDataString(mobileNo)}&sendername={Uri.EscapeDataString(senderName ?? "")}" +
                  $"&message={Uri.EscapeDataString(message)}";

        try
        {
            var response = await _httpClient.GetAsync(url);
            response.EnsureSuccessStatusCode();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send SMS to {MobileNo}.", mobileNo);
            throw;
        }
    }
}
