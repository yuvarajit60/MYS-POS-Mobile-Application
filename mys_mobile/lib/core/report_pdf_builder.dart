import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/company.dart';
import '../models/delivery_summary.dart';
import '../models/order_detail.dart';
import '../models/sales_order_summary.dart';
import '../models/trip_entry_detail.dart';
import '../models/trip_entry_line.dart';
import '../models/trip_entry_summary.dart';

/// Builds printable A4 PDFs — a company letterhead block up top, then either
/// a Summary table (all orders in a period) or a single Order Detail
/// (invoice-style, reached by tapping a Summary row).
class ReportPdfBuilder {
  static final _dateFormat = DateFormat('dd-MMM-yyyy');
  static final _timeFormat = DateFormat('HH:mm');
  static final _amountFormat = NumberFormat('#,##0.00');

  static const _pageFormat = PdfPageFormat.a4;
  static final _margin = const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28);

  static Future<pw.Document> buildSummary({
    required List<SalesOrderSummary> rows,
    required Company? company,
    required String? customerName,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final doc = pw.Document();
    final total = rows.fold<double>(0, (sum, r) => sum + r.netAmount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: _margin,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _companyHeader(company),
            pw.SizedBox(height: 10),
            pw.Text('Sales Order Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Period: ${_dateFormat.format(fromDate)} to ${_dateFormat.format(toDate)}'
              '${customerName != null ? '   |   Customer: $customerName' : '   |   All Customers'}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Entry No', 'Date', 'Customer', 'Mobile', 'Net Amount'],
            data: rows
                .map((r) => [
                      r.entryNo,
                      _dateFormat.format(r.entryDate),
                      r.customerName,
                      r.mobileNo,
                      _amountFormat.format(r.netAmount),
                    ])
                .toList(),
            cellAlignments: {4: pw.Alignment.centerRight},
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFDC92A)),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Grand Total: ${_amountFormat.format(total)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );

    return doc;
  }

  static Future<pw.Document> buildOrderDetail({
    required OrderDetail order,
    required Company? company,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: _margin,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _companyHeader(company),
            pw.SizedBox(height: 10),
            pw.Text('Sales Order', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(order.customerName, style: const pw.TextStyle(fontSize: 10)),
                      if (order.mobileNo.isNotEmpty) pw.Text(order.mobileNo, style: const pw.TextStyle(fontSize: 10)),
                      if (order.shippingAddress.isNotEmpty)
                        pw.Text(order.shippingAddress, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Entry No: ${order.entryNo}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Date: ${_dateFormat.format(order.entryDate)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Product', 'Qty', 'Rate', 'CGST', 'SGST', 'Amount'],
            data: order.lines
                .map((l) => [
                      l.productName,
                      l.qty == l.qty.roundToDouble() ? l.qty.toInt().toString() : l.qty.toString(),
                      _amountFormat.format(l.rate),
                      _amountFormat.format(l.cgstAmount),
                      _amountFormat.format(l.sgstAmount),
                      _amountFormat.format(l.totalAmount),
                    ])
                .toList(),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFDC92A)),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Taxable Value: ${_amountFormat.format(order.taxableValue)}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Total Tax: ${_amountFormat.format(order.totalTax)}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Round Off: ${_amountFormat.format(order.roundOff)}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text('Net Amount: ${_amountFormat.format(order.netAmount)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );

    return doc;
  }

  static Future<pw.Document> buildTripEntrySummary({
    required List<TripEntrySummary> rows,
    required Company? company,
    required String? customerName,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final doc = pw.Document();
    final total = rows.fold<double>(0, (sum, r) => sum + r.netAmount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: _margin,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _companyHeader(company),
            pw.SizedBox(height: 10),
            pw.Text('Trip Entry Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Period: ${_dateFormat.format(fromDate)} to ${_dateFormat.format(toDate)}'
              '${customerName != null ? '   |   Customer: $customerName' : '   |   All Customers'}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Entry No', 'Date', 'Customer', 'Site', 'Driver', 'Net Amount'],
            data: rows
                .map((r) => [
                      r.entryNo,
                      _dateFormat.format(r.entryDate),
                      r.customerName,
                      r.siteName,
                      r.driverName,
                      _amountFormat.format(r.netAmount),
                    ])
                .toList(),
            cellAlignments: {5: pw.Alignment.centerRight},
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFDC92A)),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Grand Total: ${_amountFormat.format(total)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );

    return doc;
  }

  static Future<pw.Document> buildTripEntryDetail({
    required TripEntryDetail tripEntry,
    required Company? company,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: _margin,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _companyHeader(company),
            pw.SizedBox(height: 10),
            pw.Text('Trip Entry', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(tripEntry.customerName, style: const pw.TextStyle(fontSize: 10)),
                      if (tripEntry.mobileNo.isNotEmpty) pw.Text(tripEntry.mobileNo, style: const pw.TextStyle(fontSize: 10)),
                      if (tripEntry.siteName.isNotEmpty) pw.Text('Site: ${tripEntry.siteName}', style: const pw.TextStyle(fontSize: 10)),
                      if (tripEntry.driverName.isNotEmpty) pw.Text('Driver: ${tripEntry.driverName}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Entry No: ${tripEntry.entryNo}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Date: ${_dateFormat.format(tripEntry.entryDate)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Product', 'Usage', 'Vehicle', 'Qty', 'Rate', 'CGST', 'SGST', 'Amount'],
            data: tripEntry.lines
                .map((l) => [
                      l.productName,
                      _usageText(l),
                      l.vehicleName ?? '-',
                      l.qty == l.qty.roundToDouble() ? l.qty.toInt().toString() : l.qty.toString(),
                      _amountFormat.format(l.rate),
                      _amountFormat.format(l.cgstAmount),
                      _amountFormat.format(l.sgstAmount),
                      _amountFormat.format(l.totalAmount),
                    ])
                .toList(),
            cellAlignments: {
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
            },
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFDC92A)),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Taxable Value: ${_amountFormat.format(tripEntry.taxableValue)}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Total Tax: ${_amountFormat.format(tripEntry.totalTax)}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Round Off: ${_amountFormat.format(tripEntry.roundOff)}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text('Net Amount: ${_amountFormat.format(tripEntry.netAmount)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );

    return doc;
  }

  static Future<pw.Document> buildDeliverySummary({
    required List<DeliverySummary> rows,
    required Company? company,
    required String? customerName,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: _margin,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _companyHeader(company),
            pw.SizedBox(height: 10),
            pw.Text('Delivery Report', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Period: ${_dateFormat.format(fromDate)} to ${_dateFormat.format(toDate)}'
              '${customerName != null ? '   |   Customer: $customerName' : '   |   All Customers'}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Delivery No', 'Date', 'Sales Order', 'Customer', 'Product', 'Delivered', 'Balance', 'Driver', 'Vehicle'],
            data: rows
                .map((r) => [
                      r.deliveryNo,
                      _dateFormat.format(r.deliveryDate),
                      r.salesOrderNo,
                      r.customerName,
                      r.productName,
                      _amountFormat.format(r.deliveryQty),
                      _amountFormat.format(r.balanceQty),
                      r.driverName,
                      r.vehicleNumber ?? '-',
                    ])
                .toList(),
            cellAlignments: {4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight},
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFDC92A)),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );

    return doc;
  }

  static String _usageText(TripEntryDetailLine l) {
    if (l.meterOrHours == MeterOrHours.hours) {
      final start = l.timeStart != null ? _timeFormat.format(l.timeStart!) : '-';
      final close = l.timeClose != null ? _timeFormat.format(l.timeClose!) : '-';
      return 'Hours: $start-$close';
    }
    final start = l.meterStart?.toStringAsFixed(0) ?? '-';
    final close = l.meterClose?.toStringAsFixed(0) ?? '-';
    return 'Meter: $start-$close';
  }

  static pw.Widget _companyHeader(Company? company) {
    if (company == null) {
      return pw.Text('MYS Sales', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(company.companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
        if (company.address.isNotEmpty)
          pw.Text(company.address.replaceAll('\n', ', '), style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          [
            if (company.phoneNo.isNotEmpty) 'Ph: ${company.phoneNo}',
            if (company.gstIn.isNotEmpty) 'GSTIN: ${company.gstIn}',
          ].join('   '),
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }
}
