namespace AMSEL.MobileApi.Data.Dto;

/// <summary>MeterOrHoursId: 1 = Hours, 2 = Meter — see 003_trip_entry.sql for why this isn't a lookup table.</summary>
public record TripEntryLineRequest(
    int ProductId,
    int MeterOrHoursId,
    DateTime? TimeStart,
    DateTime? TimeClose,
    decimal? MeterStart,
    decimal? MeterClose,
    int? VehicleId,
    decimal Qty,
    decimal Rate);

public record CreateTripEntryRequest(
    int CustomerId,
    string MobileNo,
    int SiteId,
    int DriverEmployeeId,
    string TripNo,
    DateTime TripDate,
    List<TripEntryLineRequest> Lines);

public record CreateTripEntryResponse(int TripEntryId, string EntryNo);
