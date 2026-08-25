namespace AMSEL.MobileApi.Data.Dto;

public record TripEntrySummaryDto(
    int TripEntryId,
    string EntryNo,
    DateTime EntryDate,
    string CustomerName,
    string MobileNo,
    string SiteName,
    string DriverName,
    decimal NetAmount);

/// <summary>MeterOrHoursId: 1 = Hours, 2 = Meter — see 003_trip_entry.sql.</summary>
public record TripEntryLineDetailDto(
    string ProductName,
    decimal Qty,
    decimal Rate,
    int MeterOrHoursId,
    DateTime? TimeStart,
    DateTime? TimeClose,
    decimal? MeterStart,
    decimal? MeterClose,
    string? VehicleName,
    decimal TaxableValue,
    decimal CgstAmount,
    decimal SgstAmount,
    decimal TotalAmount);

public record TripEntryDetailDto(
    int TripEntryId,
    string EntryNo,
    DateTime EntryDate,
    string CustomerName,
    string MobileNo,
    string SiteName,
    string DriverName,
    decimal TaxableValue,
    decimal TotalTax,
    decimal RoundOff,
    decimal NetAmount,
    List<TripEntryLineDetailDto> Lines);

public record TripEntryNumberDto(int TripEntryId, string EntryNo);
