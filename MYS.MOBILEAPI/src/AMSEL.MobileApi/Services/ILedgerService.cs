using System.Data;
using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ILedgerService
{
    Task<IReadOnlyList<LedgerEntryDto>> GetAsync(int locationId, int customerId, DateTime? fromDate, DateTime? toDate);
}

/// <summary>
/// Customer ledger — Delivery rows (from DELIVERY_DETAILS, valued
/// proportionally against each line's SALESORDER_DETAILS.TOTALAMOUNT since
/// DELIVERY_DETAILS itself carries no amount) unioned with Payment rows
/// (from PAYMENT_DETAILS), with a running Outstanding Amount. See
/// SP_MOBILE_GET_CUSTOMER_LEDGER (017_payment_details.sql) for why that
/// running balance is computed over the customer's entire history rather
/// than just the optional fromDate/toDate window passed here — the filter
/// only narrows which rows come back, it never resets the balance on them.
/// </summary>
public class LedgerService : ILedgerService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public LedgerService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<LedgerEntryDto>> GetAsync(int locationId, int customerId, DateTime? fromDate, DateTime? toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rows = await connection.QueryAsync<LedgerEntryDto>(
            "dbo.SP_MOBILE_GET_CUSTOMER_LEDGER",
            new
            {
                LOCATIONID = locationId,
                CUSTOMERID = customerId,
                FROMDATE = fromDate?.Date,
                TODATE = toDate?.Date,
            },
            commandType: CommandType.StoredProcedure);

        return rows.ToList();
    }
}
