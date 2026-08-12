namespace AMSEL.MobileApi.Data.Dto;

public record CustomerDto(int CustomerId, string CustomerName, string MobileNo);

public record CustomerDetailDto(
    int CustomerId,
    string CustomerName,
    string MobileNo,
    int CityId,
    string CityName,
    string Address);

public record CreateCustomerRequest(string CustomerName, string MobileNo, int CityId, string? Address);

public record UpdateCustomerRequest(string CustomerName, string MobileNo, int CityId, string? Address);

public record CityDto(int CityId, string CityName);
