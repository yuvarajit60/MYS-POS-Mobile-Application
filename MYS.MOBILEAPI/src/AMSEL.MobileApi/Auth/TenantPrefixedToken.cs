namespace AMSEL.MobileApi.Auth;

/// <summary>
/// Wraps a raw refresh token with its tenant code (e.g. "AMS_ERP:base64...")
/// so a later /api/auth/refresh call can resolve the tenant without any
/// directory lookup keyed on something else — at that point the access
/// token (and its "tenant" claim) has already expired, and the presented
/// refresh token is the only thing the client still has. The tenant code
/// itself isn't secret (it's already visible in the JWT while the access
/// token is live), so prefixing it in plain text here doesn't weaken
/// anything — only the raw token half is checked against a stored hash.
/// </summary>
public static class TenantPrefixedToken
{
    private const char Separator = ':';

    public static string Wrap(string tenantCode, string rawToken) => $"{tenantCode}{Separator}{rawToken}";

    public static bool TryUnwrap(string presented, out string tenantCode, out string rawToken)
    {
        var separatorIndex = presented.IndexOf(Separator);
        if (separatorIndex <= 0 || separatorIndex == presented.Length - 1)
        {
            tenantCode = "";
            rawToken = "";
            return false;
        }

        tenantCode = presented[..separatorIndex];
        rawToken = presented[(separatorIndex + 1)..];
        return true;
    }
}
