using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IChangeDateService
{
    Task<ChangeDateDto> GetAsync();
}

/// <summary>
/// dbo.CHANGE_DATE is a legacy single-row "business date" table the
/// desktop app uses for its own entry dates — it can sit a day or more
/// behind the wall clock until someone there runs a "day close", so
/// mobile entries need to read it too (see db/016_current_date_entrydate.sql)
/// rather than assuming GETDATE(). Falls back to GETDATE() if the table
/// is empty/misconfigured, so a broken CHANGE_DATE never blocks the app.
/// </summary>
public class ChangeDateService : IChangeDateService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public ChangeDateService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<ChangeDateDto> GetAsync()
    {
        using var connection = _connectionFactory.CreateConnection();
        var currentDate = await connection.QueryFirstOrDefaultAsync<DateTime?>(
            "SELECT TOP 1 CURRENTDATE FROM dbo.CHANGE_DATE");

        return new ChangeDateDto(currentDate ?? DateTime.Now);
    }
}
