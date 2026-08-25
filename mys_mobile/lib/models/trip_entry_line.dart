import 'product.dart';

/// Matches the backend's METERORHOURSID convention (003_trip_entry.sql):
/// there's no lookup table for this — it's a two-way toggle in the UI.
enum MeterOrHours {
  hours(1),
  meter(2);

  final int id;
  const MeterOrHours(this.id);
}

/// A row in the trip-entry line-items grid. Qty and Rate are both mutable —
/// Rate defaults to the product's MRP but is editable per line, same
/// convention as SalesOrderLine. Only one of (timeStart/timeClose) or
/// (meterStart/meterClose) is active at a time, based on [meterOrHours].
class TripEntryLine {
  final Product product;
  MeterOrHours meterOrHours;
  DateTime? timeStart;
  DateTime? timeClose;
  double? meterStart;
  double? meterClose;
  int? vehicleId;
  String? vehicleName;
  double qty;
  double rate;

  TripEntryLine({
    required this.product,
    this.meterOrHours = MeterOrHours.hours,
    this.timeStart,
    this.timeClose,
    this.meterStart,
    this.meterClose,
    this.vehicleId,
    this.vehicleName,
    this.qty = 1,
  }) : rate = product.rate;

  double get taxableValue => rate * qty;

  double get cgstAmount => taxableValue * product.salesCgstPercentage / 100;

  double get sgstAmount => taxableValue * product.salesSgstPercentage / 100;

  double get totalAmount => taxableValue + cgstAmount + sgstAmount;
}
