import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/company_provider.dart';
import '../core/report_pdf_builder.dart';
import '../models/sales_detail.dart';
import '../services/sales_report_service.dart';

/// Drill-down from a Summary row on the Sales Report screen — shows one
/// Sales entry's full line items and lets the rep print just that invoice.
/// Mirrors OrderDetailScreen.
class SalesDetailScreen extends StatefulWidget {
  final int salesId;
  const SalesDetailScreen({super.key, required this.salesId});

  @override
  State<SalesDetailScreen> createState() => _SalesDetailScreenState();
}

class _SalesDetailScreenState extends State<SalesDetailScreen> {
  final _reportService = SalesReportService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

  bool _loading = true;
  String? _error;
  SalesDetail? _sales;

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
      final sales = await _reportService.getSalesDetail(widget.salesId);
      if (!mounted) return;
      setState(() => _sales = sales);
    } on SalesReportServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<dynamic> _buildDoc() {
    return ReportPdfBuilder.buildSalesDetail(sales: _sales!, company: CompanyProvider.instance.company);
  }

  Future<void> _print() async {
    final doc = await _buildDoc();
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  Future<void> _share() async {
    final doc = await _buildDoc();
    await Printing.sharePdf(bytes: await doc.save(), filename: 'sales_detail.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_sales?.entryNo ?? 'Sales Entry')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildContent(_sales!),
      bottomNavigationBar: _sales == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _share,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _print,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildContent(SalesDetail sales) {
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
                  Text(sales.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  if (sales.mobileNo.isNotEmpty) Text(sales.mobileNo),
                  const SizedBox(height: 8),
                  Text('Entry No: ${sales.entryNo}'),
                  Text('Date: ${_dateFormat.format(sales.entryDate)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Products', style: Theme.of(context).textTheme.titleMedium),
          for (final line in sales.lines)
            Card(
              child: ListTile(
                title: Text(line.productName),
                subtitle: Text('Qty: ${line.qty.toStringAsFixed(0)} x ${line.rate.toStringAsFixed(2)}'),
                trailing: Text(line.taxableValue.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          const Divider(),
          _totalRow('Taxable Value', sales.taxableValue),
          _totalRow('Total Tax', sales.totalTax),
          _totalRow('Round Off', sales.roundOff),
          const SizedBox(height: 4),
          _totalRow('Net Amount', sales.netAmount, bold: true),
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
