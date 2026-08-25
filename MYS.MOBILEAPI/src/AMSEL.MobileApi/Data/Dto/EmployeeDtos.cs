namespace AMSEL.MobileApi.Data.Dto;

public record DriverDto(int EmployeeId, string EmployeeName, string MobileNo);

public record DriverVehicleDto(int? VehicleId, string? VehicleName);
