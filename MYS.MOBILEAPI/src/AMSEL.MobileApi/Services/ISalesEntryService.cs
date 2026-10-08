using System.Data;
using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ISalesEntryService
{
    Task<IReadOnlyList<SalesEntryOptionDto>> SearchAsync(int locationId, int? customerId, DateTime fromDate, DateTime toDate);
    Task<CreateSalesEntryResponse> CreateAsync(CreateSalesEntryRequest request, int locationId, int userId, int employeeId);
}

public class InvalidSalesEntryException : Exception
{
    public InvalidSalesEntryException(string message) : base(message) { }
}

/// <summary>
/// Sales Entry consolidates existing Delivery/Trip Entry activity (not yet
/// invoiced — DELIVERY_DETAILS.ISSALES/TRIPENTRY.ISSALES = 0) into a formal
/// dbo.SALES invoice, mirroring how the desktop app's own
/// sp_SalesOrderTosales converts a Sales Order into a Sales invoice — same
/// SALES/SALES_DETAILS tables and the same shared TRANSACTIONS 'SALES'
/// sequence (dbo.SP_GENERATETRANNO), so mobile-created and desktop-created
/// Sales entries interleave in one numbering series, same as every other
/// entry type here.
///
/// A Delivery's lines carry no amount of their own — SALES_DETAILS for a
/// Delivery source is built by scaling each underlying SALESORDER_DETAILS
/// line proportionally by (DELIVERYQTY / SALESQTY), the same math the
/// Ledger and Cancel Entry already use. A Trip Entry's lines are copied
/// straight from TRIPENTRY_DETAILS (already a complete, self-contained
/// line). All selected sources must resolve to the same CUSTOMERID — a
/// Sales invoice belongs to one customer — and each source is marked
/// ISSALES = 1 once converted, so it can't be selected again.
/// </summary>
public class SalesEntryService : ISalesEntryService
{
    public const string DeliverySourceType = "Delivery";
    public const string TripEntrySourceType = "Trip Entry";

    private readonly ISqlConnectionFactory _connectionFactory;

    public SalesEntryService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<SalesEntryOptionDto>> SearchAsync(int locationId, int? customerId, DateTime fromDate, DateTime toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rows = await connection.QueryAsync<SalesEntryOptionDto>(
            """
            WITH DeliveryRows AS (
                SELECT 'Delivery' AS SourceType, DD.DELIVERYNO AS EntryNo, ISNULL(MAX(SO.CUSTOMERNAME), '') AS CustomerName,
                       MIN(DD.DELIVERDATE) AS EntryDate, SUM(DD.DELIVERYQTY) AS TotalQty,
                       SUM((SOD.TOTALAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY) AS TotalAmount,
                       CAST(MAX(CASE WHEN C.GSTIN IS NOT NULL AND LTRIM(RTRIM(C.GSTIN)) <> '' THEN 1 ELSE 0 END) AS BIT) AS CustomerHasGst
                FROM DELIVERY_DETAILS DD
                INNER JOIN SALESORDER_DETAILS SOD ON SOD.SALESORDERDETID = DD.SALESORDERDETID
                INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
                LEFT JOIN CUSTOMER C ON C.CUSTOMERID = SO.CUSTOMERID
                WHERE SO.LOCATIONID = @LocationId AND (DD.CANCEL IS NULL OR DD.CANCEL = 0) AND DD.ISSALES = 0
                  AND CAST(DD.DELIVERDATE AS DATE) BETWEEN @FromDate AND @ToDate
                  AND (@CustomerId IS NULL OR SO.CUSTOMERID = @CustomerId)
                GROUP BY DD.DELIVERYNO
            ),
            TripRows AS (
                SELECT 'Trip Entry' AS SourceType, TE.ENTRYNO AS EntryNo, ISNULL(C.CUSTOMERNAME, '') AS CustomerName,
                       TE.ENTRYDATE AS EntryDate,
                       ISNULL((SELECT SUM(TD.QTY) FROM TRIPENTRY_DETAILS TD WHERE TD.TRIPENTRYID = TE.TRIPENTRYID), 0) AS TotalQty,
                       TE.NETAMOUNT AS TotalAmount,
                       CAST(CASE WHEN C.GSTIN IS NOT NULL AND LTRIM(RTRIM(C.GSTIN)) <> '' THEN 1 ELSE 0 END AS BIT) AS CustomerHasGst
                FROM TRIPENTRY TE
                LEFT JOIN CUSTOMER C ON C.CUSTOMERID = TE.CUSTOMERID
                WHERE TE.LOCATIONID = @LocationId AND TE.CANCEL = 0 AND TE.ISSALES = 0
                  AND CAST(TE.ENTRYDATE AS DATE) BETWEEN @FromDate AND @ToDate
                  AND (@CustomerId IS NULL OR TE.CUSTOMERID = @CustomerId)
            )
            SELECT * FROM DeliveryRows
            UNION ALL
            SELECT * FROM TripRows
            ORDER BY EntryDate ASC, EntryNo ASC
            """,
            new { LocationId = locationId, CustomerId = customerId, FromDate = fromDate.Date, ToDate = toDate.Date });

        return rows.ToList();
    }

    public async Task<CreateSalesEntryResponse> CreateAsync(CreateSalesEntryRequest request, int locationId, int userId, int employeeId)
    {
        if (request.Sources is null || request.Sources.Count == 0)
            throw new InvalidSalesEntryException("Select at least one Delivery/Trip Entry entry.");

        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        int? customerId = null;
        foreach (var source in request.Sources)
        {
            int? rowCustomerId = source.SourceType switch
            {
                DeliverySourceType => await connection.ExecuteScalarAsync<int?>(
                    """
                    SELECT TOP 1 SO.CUSTOMERID
                    FROM DELIVERY_DETAILS DD
                    INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
                    WHERE DD.DELIVERYNO = @EntryNo AND SO.LOCATIONID = @LocationId
                    """,
                    new { source.EntryNo, LocationId = locationId }, transaction),

                TripEntrySourceType => await connection.ExecuteScalarAsync<int?>(
                    "SELECT TOP 1 CUSTOMERID FROM TRIPENTRY WHERE ENTRYNO = @EntryNo AND LOCATIONID = @LocationId",
                    new { source.EntryNo, LocationId = locationId }, transaction),

                _ => throw new InvalidSalesEntryException($"Unknown source type \"{source.SourceType}\"."),
            };

            if (rowCustomerId is null)
            {
                transaction.Rollback();
                throw new InvalidSalesEntryException($"{source.SourceType} entry \"{source.EntryNo}\" was not found.");
            }

            if (customerId is null)
            {
                customerId = rowCustomerId;
            }
            else if (customerId != rowCustomerId)
            {
                transaction.Rollback();
                throw new InvalidSalesEntryException("All selected entries must belong to the same customer.");
            }
        }

        var customer = await connection.QueryFirstOrDefaultAsync(
            "SELECT CUSTOMERNAME, MOBILENO FROM CUSTOMER WHERE CUSTOMERID = @CustomerId",
            new { CustomerId = customerId }, transaction);

        var genParams = new DynamicParameters();
        genParams.Add("@TRANSACTIONNAME", "SALES");
        genParams.Add("@TRANNO", dbType: DbType.String, direction: ParameterDirection.Output, size: -1);
        genParams.Add("@USERSHORTNAME", "");
        genParams.Add("@LOCATIONID", locationId);
        await connection.ExecuteAsync("dbo.SP_GENERATETRANNO", genParams, transaction, commandType: CommandType.StoredProcedure);
        var entryNo = genParams.Get<string?>("@TRANNO") ?? "";

        var salesId = await connection.QuerySingleAsync<int>(
            """
            INSERT INTO SALES
                (ENTRYNO, ENTRYDATE, SALESORDERID, LOCATIONID, COUNTERID, MOBILENO, CUSTOMERID,
                 CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
                 USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID, CUSTOMERNAME)
            OUTPUT INSERTED.SALESID
            VALUES
                (@EntryNo, GETDATE(), 0, @LocationId, 0, @MobileNo, @CustomerId,
                 @LocationId, @LocationId, @UserId, @UserId,
                 GETDATE(), GETDATE(), @EmployeeId, @EmployeeId, @CustomerName)
            """,
            new
            {
                EntryNo = entryNo,
                LocationId = locationId,
                MobileNo = (string?)customer?.MOBILENO,
                CustomerId = customerId,
                UserId = userId,
                EmployeeId = employeeId,
                CustomerName = (string?)customer?.CUSTOMERNAME,
            },
            transaction);

        foreach (var source in request.Sources)
        {
            int linesInserted;
            if (source.SourceType == DeliverySourceType)
            {
                linesInserted = await connection.ExecuteAsync(
                    """
                    INSERT INTO SALES_DETAILS
                        (SALESID, COMPANYID, COUNTERID, BARCODE, PRODUCTID, PRODUCTCODE, HSNCODE, BRANDID, TYPEID, UOMID,
                         WEIGHT, QTY, MRP, RATE, GROSSAMOUNT, DISCOUNTPERCENTAGE, DISCOUNTAMOUNT, OTHERDISCOUNTAMOUNT,
                         TAXABLEVALUE, CGSTPERCENTAGE, CGSTAMOUNT, SGSTPERCENTAGE, SGSTAMOUNT, IGSTPERCENTAGE, IGSTAMOUNT,
                         TOTALTAX, PERRATE, PRATE, TOTALAMOUNT, STOCKQTY, MFGDATE, EXPDATE, ENTRYID, PERPOINTS, SALESPOINTS,
                         SALESRETURNQTY, FREEITEM)
                    SELECT
                        @SalesId, SOD.COMPANYID, SOD.COUNTERID, SOD.BARCODE, SOD.PRODUCTID, SOD.PRODUCTCODE, SOD.HSNCODE,
                        SOD.BRANDID, SOD.TYPEID, SOD.UOMID,
                        (SOD.WEIGHT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY,
                        DD.DELIVERYQTY,
                        SOD.MRP, SOD.RATE,
                        (SOD.GROSSAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY,
                        SOD.DISCOUNTPERCENTAGE,
                        (SOD.DISCOUNTAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY,
                        (SOD.OTHERDISCOUNTAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY,
                        (SOD.TAXABLEVALUE / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY,
                        SOD.CGSTPERCENTAGE,
                        (SOD.CGSTAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY,
                        SOD.SGSTPERCENTAGE,
                        (SOD.SGSTAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY,
                        SOD.IGSTPERCENTAGE,
                        (SOD.IGSTAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY,
                        (SOD.TOTALTAX / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY,
                        SOD.PERRATE, SOD.PRATE,
                        (SOD.TOTALAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY,
                        DD.DELIVERYQTY, SOD.MFGDATE, SOD.EXPDATE, 0, SOD.PERPOINTS, SOD.SALESPOINTS, 0, SOD.FREEITEM
                    FROM DELIVERY_DETAILS DD
                    INNER JOIN SALESORDER_DETAILS SOD ON SOD.SALESORDERDETID = DD.SALESORDERDETID
                    WHERE DD.DELIVERYNO = @EntryNo AND (DD.CANCEL IS NULL OR DD.CANCEL = 0) AND DD.ISSALES = 0
                    """,
                    new { SalesId = salesId, source.EntryNo },
                    transaction);
            }
            else if (source.SourceType == TripEntrySourceType)
            {
                linesInserted = await connection.ExecuteAsync(
                    """
                    INSERT INTO SALES_DETAILS
                        (SALESID, COMPANYID, COUNTERID, BARCODE, PRODUCTID, PRODUCTCODE, HSNCODE, BRANDID, TYPEID, UOMID,
                         WEIGHT, QTY, MRP, RATE, GROSSAMOUNT, DISCOUNTPERCENTAGE, DISCOUNTAMOUNT, OTHERDISCOUNTAMOUNT,
                         TAXABLEVALUE, CGSTPERCENTAGE, CGSTAMOUNT, SGSTPERCENTAGE, SGSTAMOUNT, IGSTPERCENTAGE, IGSTAMOUNT,
                         TOTALTAX, PERRATE, PRATE, TOTALAMOUNT, STOCKQTY, MFGDATE, EXPDATE, ENTRYID, PERPOINTS, SALESPOINTS,
                         SALESRETURNQTY, FREEITEM)
                    SELECT
                        @SalesId, TD.COMPANYID, TD.COUNTERID, NULL, TD.PRODUCTID, TD.PRODUCTCODE, TD.HSNCODE,
                        TD.BRANDID, TD.TYPEID, TD.UOMID,
                        TD.WEIGHT, TD.QTY, TD.MRP, TD.RATE, TD.GROSSAMOUNT, 0, 0, 0,
                        TD.TAXABLEVALUE, TD.CGSTPERCENTAGE, TD.CGSTAMOUNT, TD.SGSTPERCENTAGE, TD.SGSTAMOUNT,
                        TD.IGSTPERCENTAGE, TD.IGSTAMOUNT, TD.TOTALTAX, TD.PERRATE, TD.PRATE, TD.TOTALAMOUNT,
                        TD.QTY, NULL, NULL, 0, 0, 0, 0, 0
                    FROM TRIPENTRY_DETAILS TD
                    INNER JOIN TRIPENTRY TE ON TE.TRIPENTRYID = TD.TRIPENTRYID
                    WHERE TE.ENTRYNO = @EntryNo AND TE.LOCATIONID = @LocationId AND TE.CANCEL = 0 AND TE.ISSALES = 0
                    """,
                    new { SalesId = salesId, source.EntryNo, LocationId = locationId },
                    transaction);
            }
            else
            {
                transaction.Rollback();
                throw new InvalidSalesEntryException($"Unknown source type \"{source.SourceType}\".");
            }

            if (linesInserted == 0)
            {
                transaction.Rollback();
                throw new InvalidSalesEntryException(
                    $"{source.SourceType} entry \"{source.EntryNo}\" has no pending lines to convert (it may already be part of a Sales entry).");
            }

            int markedRows;
            if (source.SourceType == DeliverySourceType)
            {
                markedRows = await connection.ExecuteAsync(
                    "UPDATE DELIVERY_DETAILS SET ISSALES = 1 WHERE DELIVERYNO = @EntryNo AND ISSALES = 0",
                    new { source.EntryNo },
                    transaction);
            }
            else
            {
                markedRows = await connection.ExecuteAsync(
                    "UPDATE TRIPENTRY SET ISSALES = 1 WHERE ENTRYNO = @EntryNo AND LOCATIONID = @LocationId AND ISSALES = 0",
                    new { source.EntryNo, LocationId = locationId },
                    transaction);
            }

            if (markedRows == 0)
            {
                transaction.Rollback();
                throw new InvalidSalesEntryException($"Could not mark {source.SourceType} entry \"{source.EntryNo}\" as sold.");
            }
        }

        await connection.ExecuteAsync(
            """
            UPDATE SALES
            SET TAXABLEVALUE = T.TaxableValue, TOTALTAX = T.TotalTax, ITEMVALUE = T.ItemValue,
                DISCOUNTAMOUNT = T.DiscountAmount, NETAMOUNT = T.NetAmount
            FROM SALES S
            CROSS APPLY (
                SELECT ISNULL(SUM(SD.TAXABLEVALUE), 0) AS TaxableValue, ISNULL(SUM(SD.TOTALTAX), 0) AS TotalTax,
                       ISNULL(SUM(SD.GROSSAMOUNT), 0) AS ItemValue, ISNULL(SUM(SD.DISCOUNTAMOUNT), 0) AS DiscountAmount,
                       ISNULL(SUM(SD.TOTALAMOUNT), 0) AS NetAmount
                FROM SALES_DETAILS SD WHERE SD.SALESID = S.SALESID
            ) T
            WHERE S.SALESID = @SalesId
            """,
            new { SalesId = salesId },
            transaction);

        transaction.Commit();

        return new CreateSalesEntryResponse(entryNo);
    }
}
