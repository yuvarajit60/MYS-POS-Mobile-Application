using System.Data;
using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IIncomeExpenseService
{
    Task<IReadOnlyList<HeadDto>> GetHeadsAsync(string? incomeOrExpenses);
    Task<CreateIncomeExpenseResponse> CreateAsync(CreateIncomeExpenseRequest request, int locationId, int userId, int employeeId);
}

public class InvalidIncomeExpenseException : Exception
{
    public InvalidIncomeExpenseException(string message) : base(message) { }
}

/// <summary>
/// Income or Expenses — mirrors the desktop app's existing dbo.HEAD/
/// dbo.INCOMEOREXPENSES feature exactly, using the same shared
/// TRANSACTIONS 'INCOMEOREXPENSES' sequence (dbo.SP_GENERATETRANNO).
///
/// Desktop only ever free-types PARTICULARS (e.g. "KUMAR ADVANCE"). The
/// mobile app instead picks a structured Employee when the Head is
/// "SALARY ADVANCE" and a structured Vehicle when the Head is "FUEL",
/// storing the id in the new EMPLOYEEID/VEHICLEID columns (see
/// 031_income_or_expenses.sql) while still composing a sensible
/// PARTICULARS string ("{Name} {typed particulars}") so the entry still
/// reads naturally on the desktop side, which knows nothing about the new
/// columns.
/// </summary>
public class IncomeExpenseService : IIncomeExpenseService
{
    private const string SalaryAdvanceHead = "SALARY ADVANCE";
    private const string FuelHead = "FUEL";

    private readonly ISqlConnectionFactory _connectionFactory;

    public IncomeExpenseService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<HeadDto>> GetHeadsAsync(string? incomeOrExpenses)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rows = await connection.QueryAsync<HeadDto>(
            """
            SELECT HEADID AS HeadId, ISNULL(HEADNAME, '') AS HeadName, ISNULL(INCOMEOREXPENSES, '') AS IncomeOrExpenses
            FROM HEAD
            WHERE STATUS = 1
              AND (@IncomeOrExpenses IS NULL OR INCOMEOREXPENSES = @IncomeOrExpenses)
            ORDER BY HEADNAME
            """,
            new { IncomeOrExpenses = incomeOrExpenses });

        return rows.ToList();
    }

    public async Task<CreateIncomeExpenseResponse> CreateAsync(CreateIncomeExpenseRequest request, int locationId, int userId, int employeeId)
    {
        if (request.Amount <= 0)
            throw new InvalidIncomeExpenseException("Amount must be greater than zero.");

        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        var headName = await connection.ExecuteScalarAsync<string?>(
            "SELECT HEADNAME FROM HEAD WHERE HEADID = @HeadId AND STATUS = 1",
            new { request.HeadId }, transaction);

        if (headName is null)
        {
            transaction.Rollback();
            throw new InvalidIncomeExpenseException("Select a valid head.");
        }

        var trimmedHeadName = headName.Trim();
        string? employeeName = null;
        string? vehicleName = null;

        if (string.Equals(trimmedHeadName, SalaryAdvanceHead, StringComparison.OrdinalIgnoreCase))
        {
            if (request.EmployeeId is null)
            {
                transaction.Rollback();
                throw new InvalidIncomeExpenseException("Select an employee for Salary Advance.");
            }

            employeeName = await connection.ExecuteScalarAsync<string?>(
                "SELECT EMPLOYEENAME FROM EMPLOYEE WHERE EMPLOYEEID = @EmployeeId AND STATUS = 1",
                new { request.EmployeeId }, transaction);

            if (employeeName is null)
            {
                transaction.Rollback();
                throw new InvalidIncomeExpenseException("Selected employee was not found.");
            }
        }
        else if (string.Equals(trimmedHeadName, FuelHead, StringComparison.OrdinalIgnoreCase))
        {
            if (request.VehicleId is null)
            {
                transaction.Rollback();
                throw new InvalidIncomeExpenseException("Select a vehicle for Fuel.");
            }

            vehicleName = await connection.ExecuteScalarAsync<string?>(
                "SELECT VEHICLENAME FROM VEHICLE WHERE VEHICLEID = @VehicleId AND STATUS = 1",
                new { request.VehicleId }, transaction);

            if (vehicleName is null)
            {
                transaction.Rollback();
                throw new InvalidIncomeExpenseException("Selected vehicle was not found.");
            }
        }

        var particulars = BuildParticulars(employeeName ?? vehicleName, request.Particulars);

        var genParams = new DynamicParameters();
        genParams.Add("@TRANSACTIONNAME", "INCOMEOREXPENSES");
        genParams.Add("@TRANNO", dbType: DbType.String, direction: ParameterDirection.Output, size: -1);
        genParams.Add("@USERSHORTNAME", "");
        genParams.Add("@LOCATIONID", locationId);
        await connection.ExecuteAsync("dbo.SP_GENERATETRANNO", genParams, transaction, commandType: CommandType.StoredProcedure);
        var entryNo = genParams.Get<string?>("@TRANNO") ?? "";

        await connection.ExecuteAsync(
            """
            INSERT INTO INCOMEOREXPENSES
                (ENTRYNO, ENTRYDATE, ENTRYTIME, LOCATIONID, COMPANYID, INCOMEOREXPENSES, HEADID, PARTICULARS, AMOUNT,
                 EMPLOYEEID, VEHICLEID,
                 CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
                 USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
            VALUES
                (@EntryNo, @EntryDate, GETDATE(), @LocationId, 1, @IncomeOrExpenses, @HeadId, @Particulars, @Amount,
                 @EmployeeId, @VehicleId,
                 @LocationId, @LocationId, @UserId, @UserId,
                 GETDATE(), GETDATE(), @AuditEmployeeId, @AuditEmployeeId)
            """,
            new
            {
                EntryNo = entryNo,
                request.EntryDate,
                LocationId = locationId,
                request.IncomeOrExpenses,
                request.HeadId,
                Particulars = particulars,
                request.Amount,
                request.EmployeeId,
                request.VehicleId,
                UserId = userId,
                AuditEmployeeId = employeeId,
            },
            transaction);

        transaction.Commit();

        return new CreateIncomeExpenseResponse(entryNo);
    }

    private static string? BuildParticulars(string? name, string? typedParticulars)
    {
        var parts = new[] { name, typedParticulars }.Where(p => !string.IsNullOrWhiteSpace(p));
        var combined = string.Join(" ", parts).Trim();
        if (combined.Length == 0) return null;
        return combined.Length > 50 ? combined[..50] : combined;
    }
}
