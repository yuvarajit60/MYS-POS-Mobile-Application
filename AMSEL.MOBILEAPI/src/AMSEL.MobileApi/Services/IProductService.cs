using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IProductService
{
    Task<IReadOnlyList<ProductDto>> SearchAsync(string? search);
    Task<ProductDto> CreateAsync(CreateProductRequest request, string username, int locationId, int userId, int employeeId);
}

/// <summary>
/// Sales-order product data comes straight from dbo.PRODUCT (MRP, tax %) —
/// no dbo.STOCK_DETAILS join. Stock availability is intentionally not a
/// precondition for a field rep to take a draft order; that's enforced later
/// at the existing SALESORDERTOSALES conversion step.
/// </summary>
public class ProductService : IProductService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public ProductService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<ProductDto>> SearchAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<ProductDto>(
            """
            SELECT TOP 50
                   PRODUCTID AS ProductId,
                   PRODUCTNAME AS ProductName,
                   MRP AS Rate,
                   SALESCGSTPERCENTAGE AS SalesCgstPercentage,
                   SALESSGSTPERCENTAGE AS SalesSgstPercentage
            FROM PRODUCT
            WHERE STATUS = 1
              AND (@Search IS NULL OR PRODUCTNAME LIKE @Like)
            ORDER BY PRODUCTNAME
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }

    /// <summary>
    /// Creates both dbo.PRODUCT and a matching dbo.PRODUCT_DETAILS row (kept
    /// in sync at creation time; PRODUCT is now the source of truth read at
    /// sales-order time, per the redesign). Every column not explicitly
    /// supplied here has a DB-level default of 0 (confirmed against the
    /// live schema), so only the mandatory fields need to be set.
    /// </summary>
    public async Task<ProductDto> CreateAsync(CreateProductRequest request, string username, int locationId, int userId, int employeeId)
    {
        var cgst = request.SalesGstPercentage / 2m;
        var sgst = request.SalesGstPercentage / 2m;

        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        var productId = await connection.QuerySingleAsync<int>(
            """
            INSERT INTO PRODUCT
                (PRODUCTNAME, PRINTNAME, PRODUCTGROUPID, BRANDID, TYPEID, UOMID, MRP,
                 SALESCGSTPERCENTAGE, SALESSGSTPERCENTAGE, STATUS,
                 LOCATIONID, CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
                 USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
            OUTPUT INSERTED.PRODUCTID
            VALUES
                (@ProductName, @ProductName, @ProductGroupId, @BrandId, @TypeId, 1, @Mrp,
                 @Cgst, @Sgst, 1,
                 @LocationId, @LocationId, @LocationId, @UserId, @UserId,
                 GETDATE(), GETDATE(), @EmployeeId, @EmployeeId)
            """,
            new
            {
                request.ProductName,
                request.ProductGroupId,
                request.BrandId,
                request.TypeId,
                request.Mrp,
                Cgst = cgst,
                Sgst = sgst,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            },
            transaction);

        await connection.ExecuteAsync(
            """
            INSERT INTO PRODUCT_DETAILS
                (PRODUCTID, PRODUCTNAME, SALE_RATE, RETAIL_RATE, PURCHASE_RATE,
                 VALID_START_DATE, VALID_END_DATE, CREATE_DATE, CREATE_USER, VALID)
            VALUES
                (@ProductId, @ProductName, @Mrp, 0, 0,
                 GETDATE(), NULL, GETDATE(), @Username, 1)
            """,
            new { ProductId = productId, request.ProductName, request.Mrp, Username = username },
            transaction);

        transaction.Commit();

        return new ProductDto(productId, request.ProductName, request.Mrp, cgst, sgst);
    }
}
