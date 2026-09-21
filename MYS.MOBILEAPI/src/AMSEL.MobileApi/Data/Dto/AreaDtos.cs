namespace AMSEL.MobileApi.Data.Dto;

public record AreaDto(int AreaId, string AreaName, int CityId, string CityName);

public record CreateAreaRequest(string AreaName, int CityId);

public record UpdateAreaRequest(string AreaName, int CityId);
