using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IAuthService
{
    Task<AuthenticatedUser?> ValidatePasswordAsync(string username, string password);
    Task<AuthenticatedUser?> FindByUsernameAsync(string username);
    Task<AuthenticatedUser?> FindByIdAsync(int userId);
    Task<AuthenticatedUser?> FindByMobileNoAsync(string mobileNo);
}

/// <summary>
/// Mirrors the desktop app's login join (AMSEL.WINAPP.STARTUP.LOGINSCREEN: USERS -> LOCATION,
/// EMPLOYEE, BRANCH) but with a parameterized query instead of string concatenation.
/// Password comparison stays plaintext-equality for parity with the existing desktop behavior.
/// </summary>
public class AuthService : IAuthService
{
    private const string UserQuery =
        """
        SELECT USR.USERID, USR.USERNAME, USR.LOCATIONID, USR.EMPLOYEEID,
               ISNULL(EMP.EMPLOYEENAME, '') AS EmployeeName, ISNULL(EMP.MOBILENO, '') AS MobileNo,
               BR.BRANCHID
        FROM USERS USR
        INNER JOIN LOCATION LOC ON LOC.LOCATIONID = USR.LOCATIONID
        LEFT OUTER JOIN EMPLOYEE EMP ON EMP.EMPLOYEEID = USR.EMPLOYEEID
        INNER JOIN BRANCH BR ON LOC.BRANCHID = BR.BRANCHID
        WHERE USR.USERNAME = @Username AND USR.STATUS = 1
        """;

    private const string UserByIdQuery =
        """
        SELECT USR.USERID, USR.USERNAME, USR.LOCATIONID, USR.EMPLOYEEID,
               ISNULL(EMP.EMPLOYEENAME, '') AS EmployeeName, ISNULL(EMP.MOBILENO, '') AS MobileNo,
               BR.BRANCHID
        FROM USERS USR
        INNER JOIN LOCATION LOC ON LOC.LOCATIONID = USR.LOCATIONID
        LEFT OUTER JOIN EMPLOYEE EMP ON EMP.EMPLOYEEID = USR.EMPLOYEEID
        INNER JOIN BRANCH BR ON LOC.BRANCHID = BR.BRANCHID
        WHERE USR.USERID = @UserId AND USR.STATUS = 1
        """;

    private const string UserByMobileNoQuery =
        """
        SELECT TOP 1 USR.USERID, USR.USERNAME, USR.LOCATIONID, USR.EMPLOYEEID,
               EMP.EMPLOYEENAME AS EmployeeName, EMP.MOBILENO AS MobileNo,
               BR.BRANCHID
        FROM USERS USR
        INNER JOIN LOCATION LOC ON LOC.LOCATIONID = USR.LOCATIONID
        INNER JOIN EMPLOYEE EMP ON EMP.EMPLOYEEID = USR.EMPLOYEEID
        INNER JOIN BRANCH BR ON LOC.BRANCHID = BR.BRANCHID
        WHERE EMP.MOBILENO = @MobileNo AND USR.STATUS = 1
        ORDER BY USR.USERID
        """;

    private readonly ISqlConnectionFactory _connectionFactory;

    public AuthService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<AuthenticatedUser?> ValidatePasswordAsync(string username, string password)
    {
        using var connection = _connectionFactory.CreateConnection();
        var row = await connection.QuerySingleOrDefaultAsync<UserRow>(
            UserQuery + " AND USR.PASSWORD = @Password",
            new { Username = username, Password = password });

        return row is null ? null : ToAuthenticatedUser(row);
    }

    public async Task<AuthenticatedUser?> FindByUsernameAsync(string username)
    {
        using var connection = _connectionFactory.CreateConnection();
        var row = await connection.QuerySingleOrDefaultAsync<UserRow>(UserQuery, new { Username = username });
        return row is null ? null : ToAuthenticatedUser(row);
    }

    public async Task<AuthenticatedUser?> FindByIdAsync(int userId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var row = await connection.QuerySingleOrDefaultAsync<UserRow>(UserByIdQuery, new { UserId = userId });
        return row is null ? null : ToAuthenticatedUser(row);
    }

    public async Task<AuthenticatedUser?> FindByMobileNoAsync(string mobileNo)
    {
        using var connection = _connectionFactory.CreateConnection();
        var row = await connection.QueryFirstOrDefaultAsync<UserRow>(UserByMobileNoQuery, new { MobileNo = mobileNo });
        return row is null ? null : ToAuthenticatedUser(row);
    }

    private static AuthenticatedUser ToAuthenticatedUser(UserRow row) => new(
        row.USERID, row.USERNAME, row.LOCATIONID, row.EMPLOYEEID, row.EmployeeName, row.BRANCHID, row.MobileNo);

    private record UserRow(int USERID, string USERNAME, int LOCATIONID, int EMPLOYEEID, string EmployeeName, string MobileNo, int BRANCHID);
}
