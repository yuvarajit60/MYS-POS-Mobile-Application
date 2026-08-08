import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/company_provider.dart';
import '../core/report_pdf_builder.dart';
import '../models/order_detail.dart';
import '../services/report_service.dart';

/// Drill-down from a Summary row on the Reports screen — shows one order's
/// full line items and lets the rep print just that invoice.
class OrderDetailScreen extends StatefulWidget {
  final int salesOrderId;
  const OrderDetailScreen({super.key, required this.salesOrderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _reportService = ReportService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

  bool _loading = true;
  String? _error;
  OrderDetail? _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await _reportService.getOrderDetail(widget.salesOrderId);
      if (!mounted) return;
      setState(() => _order = order);
    } on ReportServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _print() async {
    final doc = await ReportPdfBuilder.buildOrderDetail(order: _order!, company: CompanyProvider.instance.company);
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_order?.entryNo ?? 'Sales Order')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildContent(_order!),
      bottomNavigationBar: _order == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Print'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _print,
              ),
            ),
    );
  }

  Widget _buildContent(OrderDetail order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  if (order.mobileNo.isNotEmpty) Text(order.mobileNo),
                  if (order.shippingAddress.isNotEmpty) Text(order.shippingAddress),
                  const SizedBox(height: 8),
                  Text('Entry No: ${order.entryNo}'),
                  Text('Date: ${_dateFormat.format(order.entryDate)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Products', style: Theme.of(context).textTheme.titleMedium),
          for (final line in order.lines)
            Card(
              child: ListTile(
                title: Text(line.productName),
                subtitle: Text('Qty: ${line.qty.toStringAsFixed(0)} x ${line.rate.toStringAsFixed(2)}'),
                trailing: Text(line.totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          const Divider(),
          _totalRow('Taxable Value', order.taxableValue),
          _totalRow('Total Tax', order.totalTax),
          _totalRow('Round Off', order.roundOff),
          const SizedBox(height: 4),
          _totalRow('Net Amount', order.netAmount, bold: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value.toStringAsFixed(2), style: style),
        ],
      ),
    );
  }
}
