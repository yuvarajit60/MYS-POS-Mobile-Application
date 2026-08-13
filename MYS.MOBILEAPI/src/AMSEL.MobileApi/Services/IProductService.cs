using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IProductService
{
    Task<IReadOnlyList<ProductDto>> SearchAsync(string? search);
    Task<ProductDetailDto?> GetByIdAsync(int productId);
    Task<ProductDto> CreateAsync(CreateProductRequest request, string username, int locationId, int userId, int employeeId);
    Task<ProductDto> UpdateAsync(int productId, UpdateProductRequest request, string username, int userId, int employeeId);
    Task<bool> DeleteAsync(int productId, int userId, int employeeId);
}

public class DuplicateProductNameException : Exception
{
    public DuplicateProductNameException(string productName)
        : base($"A product named \"{productName}\" already exists.") { }
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

    public async Task<ProductDetailDto?> GetByIdAsync(int productId)
    {
        using var connection = _connectionFactory.CreateConnection();
        return await connection.QueryFirstOrDefaultAsync<ProductDetailDto>(
            """
            SELECT PR.PRODUCTID AS ProductId, PR.PRODUCTNAME AS ProductName, PR.MRP AS Mrp,
                   PR.PRODUCTGROUPID AS ProductGroupId, ISNULL(PG.PRODUCTGROUPNAME, '') AS ProductGroupName,
                   PR.BRANDID AS BrandId, ISNULL(BR.BRANDNAME, '') AS BrandName,
                   PR.TYPEID AS TypeId, ISNULL(TY.TYPENAME, '') AS TypeName,
                   (PR.SALESCGSTPERCENTAGE + PR.SALESSGSTPERCENTAGE) AS SalesGstPercentage
            FROM PRODUCT PR
            LEFT JOIN PRODUCTGROUP PG ON PG.PRODUCTGROUPID = PR.PRODUCTGROUPID
            LEFT JOIN BRAND BR ON BR.BRANDID = PR.BRANDID
            LEFT JOIN TYPE TY ON TY.TYPEID = PR.TYPEID
            WHERE PR.PRODUCTID = @ProductId AND PR.STATUS = 1
            """,
            new { ProductId = productId });
    }

    private async Task<bool> NameExistsAsync(Microsoft.Data.SqlClient.SqlConnection connection, string productName, int? excludingProductId, Microsoft.Data.SqlClient.SqlTransaction? transaction = null)
    {
        var count = await connection.ExecuteScalarAsync<int>(
            """
            SELECT COUNT(*) FROM PRODUCT
            WHERE STATUS = 1 AND PRODUCTNAME = @ProductName
              AND (@ExcludingProductId IS NULL OR PRODUCTID <> @ExcludingProductId)
            """,
            new { ProductName = productName, ExcludingProductId = excludingProductId },
            transaction);

        return count > 0;
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

        if (await NameExistsAsync(connection, request.ProductName, null, transaction))
            throw new DuplicateProductNameException(request.ProductName);

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

    public async Task<ProductDto> UpdateAsync(int productId, UpdateProductRequest request, string username, int userId, int employeeId)
    {
        var cgst = request.SalesGstPercentage / 2m;
        var sgst = request.SalesGstPercentage / 2m;

        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await NameExistsAsync(connection, request.ProductName, productId, transaction))
            throw new DuplicateProductNameException(request.ProductName);

        await connection.ExecuteAsync(
            """
            UPDATE PRODUCT
            SET PRODUCTNAME = @ProductName, PRINTNAME = @ProductName, MRP = @Mrp,
                PRODUCTGROUPID = @ProductGroupId, BRANDID = @BrandId, TYPEID = @TypeId,
                SALESCGSTPERCENTAGE = @Cgst, SALESSGSTPERCENTAGE = @Sgst,
                LASTMODIFYEDUSERID = @UserId, LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE PRODUCTID = @ProductId AND STATUS = 1
            """,
            new
            {
                ProductId = productId,
                request.ProductName,
                request.Mrp,
                request.ProductGroupId,
                request.BrandId,
                request.TypeId,
                Cgst = cgst,
                Sgst = sgst,
                UserId = userId,
                EmployeeId = employeeId,
            },
            transaction);

        await connection.ExecuteAsync(
            """
            UPDATE PRODUCT_DETAILS
            SET PRODUCTNAME = @ProductName, SALE_RATE = @Mrp,
                MODIFIED_DATE = GETDATE(), MODIFIED_USER = @Username
            WHERE PRODUCTID = @ProductId AND VALID = 1
            """,
            new { ProductId = productId, request.ProductName, request.Mrp, Username = username },
            transaction);

        transaction.Commit();

        return new ProductDto(productId, request.ProductName, request.Mrp, cgst, sgst);
    }

    /// <summary>Soft delete (STATUS=0) — historical SALESORDER_DETAILS rows still resolve the product name via LEFT JOIN, unaffected by this.</summary>
    public async Task<bool> DeleteAsync(int productId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rowsAffected = await connection.ExecuteAsync(
            """
            UPDATE PRODUCT
            SET STATUS = 0, LASTMODIFYEDUSERID = @UserId, LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE PRODUCTID = @ProductId AND STATUS = 1
            """,
            new { ProductId = productId, UserId = userId, EmployeeId = employeeId });

        return rowsAffected > 0;
    }
}
