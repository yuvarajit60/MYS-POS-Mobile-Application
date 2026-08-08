import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/customer.dart';
import '../models/sales_order_line.dart';

class SalesOrderException implements Exception {
  final String message;
  SalesOrderException(this.message);
}

class SalesOrderResult {
  final int salesOrderId;
  final String entryNo;
  SalesOrderResult({required this.salesOrderId, required this.entryNo});
}

class SalesOrderService {
  Future<SalesOrderResult> create({
    required Customer customer,
    required String shippingAddress,
    required List<SalesOrderLine> lines,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/sales-orders', data: {
        'customerId': customer.customerId,
        'customerName': customer.customerName,
        'mobileNo': customer.mobileNo,
        'shippingAddress': shippingAddress,
        'lines': lines.map((l) => {'productId': l.product.productId, 'qty': l.qty, 'rate': l.rate}).toList(),
      });
      final data = response.data as Map<String, dynamic>;
      return SalesOrderResult(salesOrderId: data['salesOrderId'] as int, entryNo: data['entryNo'] as String);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String) ? data['message'] as String : 'Could not save the sales order.';
      throw SalesOrderException(message);
    }
  }
}
