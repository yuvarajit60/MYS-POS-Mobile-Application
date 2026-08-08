namespace AMSEL.MobileApi.Data.Dto;

public record CustomerDto(int CustomerId, string CustomerName, string MobileNo);

public record CreateCustomerRequest(string CustomerName, string MobileNo, int CityId, string? Address);

public record CityDto(int CityId, string CityName);
