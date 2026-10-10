import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/company_provider.dart';
import '../core/report_pdf_builder.dart';
import '../models/customer.dart';
import '../models/sales_entry_number.dart';
import '../models/sales_summary.dart';
import '../services/customer_service.dart';
import '../services/sales_report_service.dart';
import 'sales_detail_screen.dart';
import 'widgets/search_picker_sheet.dart';

/// Reports on Sales entries (dbo.SALES — see Sales Entry, which creates
/// these by consolidating Delivery/Trip Entry activity). Mirrors
/// ReportsScreen (Sales Order Report).
class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final _customerService = CustomerService();
  final _reportService = SalesReportService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

  Customer? _selectedCustomer;
  SalesEntryNumber? _selectedEntryNumber;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  bool _loading = false;
  String? _error;
  List<SalesSummary>? _rows;

  double get _total => _rows?.fold<double>(0, (sum, r) => sum + r.netAmount) ?? 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _pickEntryNumber() async {
    final entryNumber = await showSearchPicker<SalesEntryNumber>(
      context: context,
      title: 'Search sales entry no (leave blank for all)',
      search: _reportService.searchEntryNumbers,
      itemLabel: (e) => e.entryNo,
    );
    if (entryNumber != null) setState(() => _selectedEntryNumber = entryNumber);
  }

  Future<void> _pickCustomer() async {
    final customer = await showSearchPicker<Customer>(
      context: context,
      title: 'Search customer (leave blank for all)',
      search: _customerService.search,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
    );
    if (customer != null) setState(() => _selectedCustomer = customer);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => isFrom ? _fromDate = picked : _toDate = picked);
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _reportService.getSummary(
        customerId: _selectedCustomer?.customerId,
        salesNo: _selectedEntryNumber?.entryNo,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } on SalesReportServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<dynamic> _buildDoc() {
    return ReportPdfBuilder.buildSalesSummary(
      rows: _rows ?? [],
      company: CompanyProvider.instance.company,
      customerName: _selectedCustomer?.customerName,
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  Future<void> _print() async {
    final doc = await _buildDoc();
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  Future<void> _share() async {
    final doc = await _buildDoc();
    await Printing.sharePdf(bytes: await doc.save(), filename: 'sales_report.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Report')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: _pickEntryNumber,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Sales Entry No',
                        suffixIcon: _selectedEntryNumber == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() => _selectedEntryNumber = null),
                              ),
                      ),
                      child: Text(_selectedEntryNumber?.entryNo ?? 'All Sales Entries'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickCustomer,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Customer',
                        suffixIcon: _selectedCustomer == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() => _selectedCustomer = null),
                              ),
                      ),
                      child: Text(_selectedCustomer?.customerName ?? 'All Customers'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isFrom: true),
                          child: InputDecorator(
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'From Date'),
                            child: Text(_dateFormat.format(_fromDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isFrom: false),
                          child: InputDecorator(
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'To Date'),
                            child: Text(_dateFormat.format(_toDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _generate,
                    child: _loading ? const CircularProgressIndicator() : const Text('Generate Report'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  if (_rows != null) _buildResults(),
                ],
              ),
            ),
          ),
          if (_rows?.isNotEmpty ?? false)
            SafeArea(
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
        ],
      ),
    );
  }

  Widget _buildResults() {
    final rows = _rows!;
    if (rows.isEmpty) return const Center(child: Text('No sales entries found for this period.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Card(
            child: ListTile(
              title: Text(row.customerName),
              subtitle: Text('${row.entryNo}  |  ${_dateFormat.format(row.entryDate)}'),
              trailing: Text(row.netAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SalesDetailScreen(salesId: row.salesId)),
              ),
            ),
          ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
