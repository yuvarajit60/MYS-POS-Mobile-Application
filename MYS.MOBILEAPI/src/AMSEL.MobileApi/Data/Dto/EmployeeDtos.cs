namespace AMSEL.MobileApi.Data.Dto;

public record DriverDto(int EmployeeId, string EmployeeName, string MobileNo);

public record DriverVehicleDto(int? VehicleId, string? VehicleName);

public record EmployeeDto(int EmployeeId, string EmployeeName, string MobileNo, bool IsDriver);

public record EmployeeDetailDto(
    int EmployeeId,
    string EmployeeName,
    string PrintName,
    string EmployeeCode,
    string Address,
    int CityId,
    string CityName,
    string PinCode,
    string PhoneNo,
    string MobileNo,
    string EmailId,
    bool IsDriver);

public record CreateEmployeeRequest(
    string EmployeeName,
    string? PrintName,
    string? EmployeeCode,
    string? Address,
    int CityId,
    string? PinCode,
    string? PhoneNo,
    string MobileNo,
    string? EmailId,
    bool IsDriver);

public record UpdateEmployeeRequest(
    string EmployeeName,
    string? PrintName,
    string? EmployeeCode,
    string? Address,
    int CityId,
    string? PinCode,
    string? PhoneNo,
    string MobileNo,
    string? EmailId,
    bool IsDriver);
