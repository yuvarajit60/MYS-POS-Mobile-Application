namespace AMSEL.MobileApi.Data.Dto;

public record ProductDto(
    int ProductId,
    string ProductName,
    decimal Rate,
    decimal SalesCgstPercentage,
    decimal SalesSgstPercentage);

public record ProductGroupDto(int ProductGroupId, string ProductGroupName);

public record BrandDto(int BrandId, string BrandName);

public record TypeDto(int TypeId, string TypeName);

public record CreateProductRequest(
    string ProductName,
    decimal Mrp,
    int ProductGroupId,
    int BrandId,
    int TypeId,
    decimal SalesGstPercentage);
