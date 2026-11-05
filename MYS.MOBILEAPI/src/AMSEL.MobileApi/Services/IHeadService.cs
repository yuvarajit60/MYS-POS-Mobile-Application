using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IHeadService
{
    Task<IReadOnlyList<HeadDto>> SearchAsync(string? search);
    Task<HeadDetailDto?> GetByIdAsync(int headId);
    Task<HeadDetailDto> CreateAsync(CreateHeadRequest request, int locationId, int userId, int employeeId);
    Task<HeadDetailDto> UpdateAsync(int headId, UpdateHeadRequest request, int locationId, int userId, int employeeId);
    Task<bool> DeleteAsync(int headId, int locationId, int userId, int employeeId);
}

public class DuplicateHeadNameException : Exception
{
    public DuplicateHeadNameException(string headName)
        : base($"A head named \"{headName}\" already exists.") { }
}

/// <summary>
/// Head Master (dbo.HEAD) — mirrors the desktop app's "Account Head
/// Master" screen, plus MAPPEDMASTER (mobile-only, see
/// 033_head_mapped_master.sql): which other master a Head pulls a picker
/// from in Income or Expenses Entry ("Employee", "Vehicle", or none).
/// </summary>
public class HeadService : IHeadService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public HeadService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<HeadDto>> SearchAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<HeadDto>(
            """
            SELECT TOP 50 HEADID AS HeadId, ISNULL(HEADNAME, '') AS HeadName, ISNULL(INCOMEOREXPENSES, '') AS IncomeOrExpenses,
                   MAPPEDMASTER AS MappedMaster
            FROM HEAD
            WHERE STATUS = 1
              AND (@Search IS NULL OR HEADNAME LIKE @Like)
            ORDER BY HEADNAME
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }

    public async Task<HeadDetailDto?> GetByIdAsync(int headId)
    {
        using var connection = _connectionFactory.CreateConnection();
        return await connection.QueryFirstOrDefaultAsync<HeadDetailDto>(
            """
            SELECT HEADID AS HeadId, ISNULL(HEADNAME, '') AS HeadName, ISNULL(PRINTNAME, '') AS PrintName,
                   ISNULL(INCOMEOREXPENSES, '') AS IncomeOrExpenses, MAPPEDMASTER AS MappedMaster, STATUS AS Status
            FROM HEAD
            WHERE HEADID = @HeadId
            """,
            new { HeadId = headId });
    }

    private async Task<bool> NameExistsAsync(Microsoft.Data.SqlClient.SqlConnection connection, string headName, int? excludingHeadId, Microsoft.Data.SqlClient.SqlTransaction? transaction = null)
    {
        var count = await connection.ExecuteScalarAsync<int>(
            """
            SELECT COUNT(*) FROM HEAD
            WHERE STATUS = 1 AND HEADNAME = @HeadName
              AND (@ExcludingHeadId IS NULL OR HEADID <> @ExcludingHeadId)
            """,
            new { HeadName = headName, ExcludingHeadId = excludingHeadId },
            transaction);

        return count > 0;
    }

    public async Task<HeadDetailDto> CreateAsync(CreateHeadRequest request, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await NameExistsAsync(connection, request.HeadName, null, transaction))
            throw new DuplicateHeadNameException(request.HeadName);

        var headId = await connection.QuerySingleAsync<int>(
            """
            INSERT INTO HEAD
                (HEADNAME, PRINTNAME, INCOMEOREXPENSES, MAPPEDMASTER, STATUS,
                 CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
                 USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
            OUTPUT INSERTED.HEADID
            VALUES
                (@HeadName, @PrintName, @IncomeOrExpenses, @MappedMaster, 1,
                 @LocationId, @LocationId, @UserId, @UserId,
                 GETDATE(), GETDATE(), @EmployeeId, @EmployeeId)
            """,
            new
            {
                request.HeadName,
                PrintName = request.PrintName ?? request.HeadName,
                request.IncomeOrExpenses,
                request.MappedMaster,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            },
            transaction);

        transaction.Commit();

        return (await GetByIdAsync(headId))!;
    }

    public async Task<HeadDetailDto> UpdateAsync(int headId, UpdateHeadRequest request, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await NameExistsAsync(connection, request.HeadName, headId, transaction))
            throw new DuplicateHeadNameException(request.HeadName);

        await connection.ExecuteAsync(
            """
            UPDATE HEAD
            SET HEADNAME = @HeadName, PRINTNAME = @PrintName, INCOMEOREXPENSES = @IncomeOrExpenses,
                MAPPEDMASTER = @MappedMaster, STATUS = @Status,
                MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE HEADID = @HeadId
            """,
            new
            {
                HeadId = headId,
                request.HeadName,
                PrintName = request.PrintName ?? request.HeadName,
                request.IncomeOrExpenses,
                request.MappedMaster,
                Status = request.Status ? 1 : 0,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            },
            transaction);

        transaction.Commit();

        return (await GetByIdAsync(headId))!;
    }

    /// <summary>Soft delete (STATUS=0) — matches CUSTOMER/PRODUCT/SITE's convention; existing INCOMEOREXPENSES rows keep their own HEADID reference, unaffected.</summary>
    public async Task<bool> DeleteAsync(int headId, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rowsAffected = await connection.ExecuteAsync(
            """
            UPDATE HEAD
            SET STATUS = 0, MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE HEADID = @HeadId AND STATUS = 1
            """,
            new { HeadId = headId, LocationId = locationId, UserId = userId, EmployeeId = employeeId });

        return rowsAffected > 0;
    }
}
