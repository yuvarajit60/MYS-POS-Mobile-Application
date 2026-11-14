import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/app_theme.dart';
import '../../core/company_provider.dart';
import '../../core/report_pdf_builder.dart';
import '../../models/customer.dart';
import '../../models/entry_number.dart';
import '../../models/sales_order_summary.dart';
import '../../screens/graph_screen.dart';
import '../../screens/order_detail_screen.dart';
import '../../services/customer_service.dart';
import '../../services/report_service.dart';
import '../widgets/web_search_picker.dart';

/// Web equivalent of reports_screen.dart (mobile) — Sales Order Report.
/// The Graph view (GraphScreen) is reused as-is via a normal page push.
class SalesOrderReportWebScreen extends StatefulWidget {
  const SalesOrderReportWebScreen({super.key});

  @override
  State<SalesOrderReportWebScreen> createState() => _SalesOrderReportWebScreenState();
}

class _SalesOrderReportWebScreenState extends State<SalesOrderReportWebScreen> {
  final _customerService = CustomerService();
  final _reportService = ReportService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');
  static final _amountFormat = NumberFormat('#,##0.00');

  Customer? _selectedCustomer;
  EntryNumber? _selectedEntryNumber;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  bool _loading = false;
  String? _error;
  List<SalesOrderSummary>? _rows;

  double get _total => _rows?.fold<double>(0, (sum, r) => sum + r.netAmount) ?? 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _pickEntryNumber() async {
    final entryNumber = await showWebSearchPicker<EntryNumber>(
      context: context,
      title: 'Search sales order no (leave blank for all)',
      search: _reportService.searchEntryNumbers,
      itemLabel: (e) => e.entryNo,
    );
    if (entryNumber != null) setState(() => _selectedEntryNumber = entryNumber);
  }

  Future<void> _pickCustomer() async {
    final customer = await showWebSearchPicker<Customer>(
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
        salesOrderNo: _selectedEntryNumber?.entryNo,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } on ReportServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<dynamic> _buildDoc() {
    return ReportPdfBuilder.buildSummary(
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
    await Printing.sharePdf(bytes: await doc.save(), filename: 'sales_order_report.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MysColors.bgLight,
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GraphScreen())),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Graph'),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: _pickEntryNumber,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Sales Order No',
                              suffixIcon: _selectedEntryNumber == null
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => setState(() => _selectedEntryNumber = null),
                                    ),
                            ),
                            child: Text(_selectedEntryNumber?.entryNo ?? 'All Sales Orders'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _pickCustomer,
                          child: InputDecorator(
                            decoration: InputDecoration(
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
                                  decoration: const InputDecoration(labelText: 'From Date'),
                                  child: Text(_dateFormat.format(_fromDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDate(isFrom: false),
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'To Date'),
                                  child: Text(_dateFormat.format(_toDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _loading ? null : _generate,
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Generate Report'),
                              ),
                            ),
                            if (_rows?.isNotEmpty ?? false) ...[
                              const SizedBox(width: 12),
                              OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share), label: const Text('Share')),
                              const SizedBox(width: 12),
                              FilledButton.icon(onPressed: _print, icon: const Icon(Icons.print), label: const Text('Print')),
                            ],
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_rows != null) _buildResults(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final rows = _rows!;
    if (rows.isEmpty) return const Center(child: Text('No orders found for this period.'));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ...[
            for (final row in rows)
              ListTile(
                title: Text(row.customerName),
                subtitle: Text('${row.entryNo}  |  ${_dateFormat.format(row.entryDate)}'),
                trailing: Text(_amountFormat.format(row.netAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(salesOrderId: row.salesOrderId)),
                ),
              ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_amountFormat.format(_total), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
