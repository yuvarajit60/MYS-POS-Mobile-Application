import 'trip_entry_line.dart';

class TripEntryDetailLine {
  final String productName;
  final double qty;
  final double rate;
  final MeterOrHours meterOrHours;
  final DateTime? timeStart;
  final DateTime? timeClose;
  final double? meterStart;
  final double? meterClose;
  final String? vehicleName;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double totalAmount;

  TripEntryDetailLine({
    required this.productName,
    required this.qty,
    required this.rate,
    required this.meterOrHours,
    required this.timeStart,
    required this.timeClose,
    required this.meterStart,
    required this.meterClose,
    required this.vehicleName,
    required this.taxableValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.totalAmount,
  });

  factory TripEntryDetailLine.fromJson(Map<String, dynamic> json) => TripEntryDetailLine(
        productName: json['productName'] as String,
        qty: (json['qty'] as num).toDouble(),
        rate: (json['rate'] as num).toDouble(),
        meterOrHours: MeterOrHours.values.firstWhere(
          (e) => e.id == json['meterOrHoursId'] as int,
          orElse: () => MeterOrHours.hours,
        ),
        timeStart: json['timeStart'] == null ? null : DateTime.parse(json['timeStart'] as String),
        timeClose: json['timeClose'] == null ? null : DateTime.parse(json['timeClose'] as String),
        meterStart: (json['meterStart'] as num?)?.toDouble(),
        meterClose: (json['meterClose'] as num?)?.toDouble(),
        vehicleName: json['vehicleName'] as String?,
        taxableValue: (json['taxableValue'] as num).toDouble(),
        cgstAmount: (json['cgstAmount'] as num).toDouble(),
        sgstAmount: (json['sgstAmount'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
      );
}

class TripEntryDetail {
  final int tripEntryId;
  final String entryNo;
  final DateTime entryDate;
  final String customerName;
  final String mobileNo;
  final String siteName;
  final String driverName;
  final double taxableValue;
  final double totalTax;
  final double roundOff;
  final double netAmount;
  final List<TripEntryDetailLine> lines;

  TripEntryDetail({
    required this.tripEntryId,
    required this.entryNo,
    required this.entryDate,
    required this.customerName,
    required this.mobileNo,
    required this.siteName,
    required this.driverName,
    required this.taxableValue,
    required this.totalTax,
    required this.roundOff,
    required this.netAmount,
    required this.lines,
  });

  factory TripEntryDetail.fromJson(Map<String, dynamic> json) => TripEntryDetail(
        tripEntryId: json['tripEntryId'] as int,
        entryNo: json['entryNo'] as String,
        entryDate: DateTime.parse(json['entryDate'] as String),
        customerName: json['customerName'] as String,
        mobileNo: json['mobileNo'] as String? ?? '',
        siteName: json['siteName'] as String? ?? '',
        driverName: json['driverName'] as String? ?? '',
        taxableValue: (json['taxableValue'] as num).toDouble(),
        totalTax: (json['totalTax'] as num).toDouble(),
        roundOff: (json['roundOff'] as num).toDouble(),
        netAmount: (json['netAmount'] as num).toDouble(),
        lines: (json['lines'] as List).map((e) => TripEntryDetailLine.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
