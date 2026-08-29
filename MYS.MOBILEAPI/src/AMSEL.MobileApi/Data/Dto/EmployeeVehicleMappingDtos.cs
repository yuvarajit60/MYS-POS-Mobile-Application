namespace AMSEL.MobileApi.Data.Dto;

public record EmployeeVehicleMappingDto(
    int MappingId,
    int EmployeeId,
    string EmployeeName,
    int VehicleId,
    string VehicleName,
    DateTime ValidStartDate,
    DateTime? ValidEndDate);

public record CreateEmployeeVehicleMappingRequest(int EmployeeId, int VehicleId, DateTime ValidStartDate, DateTime? ValidEndDate);

public record UpdateEmployeeVehicleMappingRequest(int EmployeeId, int VehicleId, DateTime ValidStartDate, DateTime? ValidEndDate);
