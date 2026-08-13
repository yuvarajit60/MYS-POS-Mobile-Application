using System.Security.Claims;

namespace AMSEL.MobileApi.Auth;

public static class ClaimsPrincipalExtensions
{
    public static int GetUserId(this ClaimsPrincipal user) =>
        int.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier)!);

    public static int GetLocationId(this ClaimsPrincipal user) =>
        int.Parse(user.FindFirstValue("locationId")!);

    public static int GetEmployeeId(this ClaimsPrincipal user) =>
        int.Parse(user.FindFirstValue("employeeId")!);

    public static string GetUsername(this ClaimsPrincipal user) =>
        user.FindFirstValue("username")!;
}
