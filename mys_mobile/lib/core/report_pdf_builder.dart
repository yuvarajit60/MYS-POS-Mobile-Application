import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/company.dart';
import '../models/delivery_detail.dart';
import '../models/delivery_summary.dart';
import '../models/ledger_entry.dart';
import '../models/order_detail.dart';
import '../models/payment_report_entry.dart';
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
  static final _printedFormat = DateFormat('dd-MMM-yyyy, hh:mm a');
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
            headers: ['Entry No', 'Entry Date', 'Trip Date', 'Customer', 'Site', 'Driver', 'Net Amount'],
            data: rows
                .map((r) => [
                      r.entryNo,
                      _dateFormat.format(r.entryDate),
                      _dateFormat.format(r.tripDate),
                      r.customerName,
                      r.siteName,
                      r.driverName,
                      _amountFormat.format(r.netAmount),
                    ])
                .toList(),
            cellAlignments: {6: pw.Alignment.centerRight},
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
                    pw.Text('Entry Date: ${_dateFormat.format(tripEntry.entryDate)}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Trip Date: ${_dateFormat.format(tripEntry.tripDate)}', style: const pw.TextStyle(fontSize: 10)),
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
            headers: ['Delivery No', 'Date', 'Customer', 'Driver', 'Vehicle', 'Items', 'Total Qty'],
            data: rows
                .map((r) => [
                      r.deliveryNo,
                      _dateFormat.format(r.deliveryDate),
                      r.customerName,
                      r.driverName,
                      r.vehicleNumber ?? '-',
                      r.lineCount.toString(),
                      _amountFormat.format(r.totalQty),
                    ])
                .toList(),
            cellAlignments: {5: pw.Alignment.centerRight, 6: pw.Alignment.centerRight},
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFDC92A)),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Grand Total: ${_amountFormat.format(rows.fold<double>(0, (sum, r) => sum + r.totalQty))}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );

    return doc;
  }

  static Future<pw.Document> buildDeliveryDetail({
    required DeliveryDetail delivery,
    required Company? company,
  }) async {
    final doc = pw.Document();
    final totalQty = delivery.lines.fold<double>(0, (sum, l) => sum + l.deliveryQty);

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: _margin,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _companyHeader(company),
            pw.SizedBox(height: 10),
            pw.Text('Delivery', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(delivery.customerName, style: const pw.TextStyle(fontSize: 10)),
                      if (delivery.driverName.isNotEmpty) pw.Text('Driver: ${delivery.driverName}', style: const pw.TextStyle(fontSize: 10)),
                      if (delivery.vehicleNumber != null) pw.Text('Vehicle: ${delivery.vehicleNumber}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Delivery No: ${delivery.deliveryNo}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Date: ${_dateFormat.format(delivery.deliveryDate)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Sales Order', 'Product', 'Delivered', 'Balance'],
            data: delivery.lines
                .map((l) => [
                      l.salesOrderNo,
                      l.productName,
                      _amountFormat.format(l.deliveryQty),
                      _amountFormat.format(l.balanceQty),
                    ])
                .toList(),
            cellAlignments: {2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFDC92A)),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Total Qty: ${_amountFormat.format(totalQty)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );

    return doc;
  }

  /// Formal statement-style layout (page number + "Printed" timestamp in
  /// the top-right corner, a bordered "Report Totals" row at the bottom) —
  /// matches the printed-ledger reference this was modeled on. Unlike the
  /// other Summary builders, rows here are a single running ledger (see
  /// LedgerEntry/SP_MOBILE_GET_CUSTOMER_LEDGER) so they're never re-sorted
  /// or grouped by type — that would break the Outstanding Amount running
  /// balance already computed per row.
  static Future<pw.Document> buildLedgerSummary({
    required List<LedgerEntry> rows,
    required Company? company,
    required String customerName,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final doc = pw.Document();
    final printedAt = _printedFormat.format(DateTime.now());
    final totalAmount = rows.fold<double>(0, (sum, r) => sum + r.totalAmount);
    final receivedAmount = rows.fold<double>(0, (sum, r) => sum + r.receivedAmount);
    final closingBalance = rows.isEmpty ? 0.0 : rows.last.outstandingAmount;

    final periodText = (fromDate == null && toDate == null)
        ? 'All Transactions'
        : 'Period: ${fromDate != null ? _dateFormat.format(fromDate) : 'Beginning'} to ${toDate != null ? _dateFormat.format(toDate) : 'Date'}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: _margin,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _companyHeader(company)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Text('Payment Report', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ),
                pw.Text('Printed $printedAt', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('Customer: $customerName', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(periodText, style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Txn No', 'Total Amount', 'Received Amount', 'Outstanding Amount'],
            data: rows
                .map((r) => [
                      _dateFormat.format(r.txnDate),
                      r.txnType,
                      r.txnNo,
                      _amountFormat.format(r.totalAmount),
                      _amountFormat.format(r.receivedAmount),
                      _amountFormat.format(r.outstandingAmount),
                    ])
                .toList(),
            cellAlignments: {3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight},
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFDC92A)),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 1), bottom: pw.BorderSide(width: 1)),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text('Report Totals', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
                pw.Expanded(
                  child: pw.Text(_amountFormat.format(totalAmount),
                      textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
                pw.Expanded(
                  child: pw.Text(_amountFormat.format(receivedAmount),
                      textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
                pw.Expanded(
                  child: pw.Text(_amountFormat.format(closingBalance),
                      textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc;
  }

  static Future<pw.Document> buildPaymentReportSummary({
    required List<PaymentReportEntry> rows,
    required Company? company,
    required String? customerName,
    required String? paymentType,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final doc = pw.Document();
    final total = rows.fold<double>(0, (sum, r) => sum + r.amount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: _margin,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _companyHeader(company),
            pw.SizedBox(height: 10),
            pw.Text('Payment Report', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Period: ${_dateFormat.format(fromDate)} to ${_dateFormat.format(toDate)}'
              '${customerName != null ? '   |   Customer: $customerName' : '   |   All Customers'}'
              '${paymentType != null ? '   |   Type: $paymentType' : ''}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Payment No', 'Customer', 'Date', 'Type', 'Amount'],
            data: rows
                .map((r) => [
                      r.paymentNo,
                      r.customerName,
                      _dateFormat.format(r.paymentDate),
                      r.paymentType,
                      _amountFormat.format(r.amount),
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
            child: pw.Text('Total Amount: ${_amountFormat.format(total)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
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
    final start = l.meterStart?.toStringAsFixed(1) ?? '-';
    final close = l.meterClose?.toStringAsFixed(1) ?? '-';
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
