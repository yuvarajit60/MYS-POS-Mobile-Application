namespace AMSEL.MobileApi.Data.Dto;

public record SiteDto(int SiteId, string SiteName, string AreaName, int? CustomerId, string? CustomerName, string MobileNo);

public record SiteDetailDto(int SiteId, string SiteName, string AreaName, int AreaId, int CityId, string CityName, int? CustomerId, string? CustomerName);

public record CreateSiteRequest(string SiteName, string AreaName, int AreaId, int CityId);

public record UpdateSiteRequest(string SiteName, string AreaName, int AreaId, int CityId);

public record AssignSiteCustomerRequest(int? CustomerId);
