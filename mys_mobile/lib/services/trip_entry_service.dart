import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/customer.dart';
import '../models/driver.dart';
import '../models/site.dart';
import '../models/trip_entry_line.dart';

class TripEntryException implements Exception {
  final String message;
  TripEntryException(this.message);
}

class TripEntryResult {
  final int tripEntryId;
  final String entryNo;
  TripEntryResult({required this.tripEntryId, required this.entryNo});
}

class TripEntryService {
  Future<TripEntryResult> create({
    required Customer customer,
    required Site site,
    required Driver driver,
    required String tripNo,
    required DateTime tripDate,
    required List<TripEntryLine> lines,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/trip-entries', data: {
        'customerId': customer.customerId,
        'mobileNo': customer.mobileNo,
        'siteId': site.siteId,
        'driverEmployeeId': driver.employeeId,
        'tripNo': tripNo,
        'tripDate': tripDate.toIso8601String(),
        'lines': lines
            .map((l) => {
                  'productId': l.product.productId,
                  'meterOrHoursId': l.meterOrHours.id,
                  'timeStart': l.timeStart?.toIso8601String(),
                  'timeClose': l.timeClose?.toIso8601String(),
                  'meterStart': l.meterStart,
                  'meterClose': l.meterClose,
                  'vehicleId': l.vehicleId,
                  'qty': l.qty,
                  'rate': l.rate,
                })
            .toList(),
      });
      final data = response.data as Map<String, dynamic>;
      return TripEntryResult(tripEntryId: data['tripEntryId'] as int, entryNo: data['entryNo'] as String);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String) ? data['message'] as String : 'Could not save the trip entry.';
      throw TripEntryException(message);
    }
  }
}
