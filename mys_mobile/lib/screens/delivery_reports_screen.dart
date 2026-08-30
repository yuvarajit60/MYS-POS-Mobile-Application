import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/company_provider.dart';
import '../core/report_pdf_builder.dart';
import '../models/customer.dart';
import '../models/delivery_number.dart';
import '../models/delivery_summary.dart';
import '../services/customer_service.dart';
import '../services/delivery_report_service.dart';
import 'delivery_detail_screen.dart';
import 'widgets/search_picker_sheet.dart';

/// Mirrors TripEntryReportsScreen — one row per DeliveryNo (every line saved
/// in a single Delivery Entry submission shares the same number), tap to
/// drill into the individual product lines.
class DeliveryReportsScreen extends StatefulWidget {
  const DeliveryReportsScreen({super.key});

  @override
  State<DeliveryReportsScreen> createState() => _DeliveryReportsScreenState();
}

class _DeliveryReportsScreenState extends State<DeliveryReportsScreen> {
  final _customerService = CustomerService();
  final _reportService = DeliveryReportService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

  Customer? _selectedCustomer;
  DeliveryNumber? _selectedDeliveryNumber;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  bool _loading = false;
  String? _error;
  List<DeliverySummary>? _rows;

  double get _totalQty => _rows?.fold<double>(0, (sum, r) => sum + r.totalQty) ?? 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _pickDeliveryNumber() async {
    final deliveryNumber = await showSearchPicker<DeliveryNumber>(
      context: context,
      title: 'Search delivery no (leave blank for all)',
      search: _reportService.searchDeliveryNumbers,
      itemLabel: (d) => d.deliveryNo,
    );
    if (deliveryNumber != null) setState(() => _selectedDeliveryNumber = deliveryNumber);
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
        deliveryNo: _selectedDeliveryNumber?.deliveryNo,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } on DeliveryReportServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _print() async {
    final doc = await ReportPdfBuilder.buildDeliverySummary(
      rows: _rows ?? [],
      company: CompanyProvider.instance.company,
      customerName: _selectedCustomer?.customerName,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Report')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: _pickDeliveryNumber,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Delivery No',
                        suffixIcon: _selectedDeliveryNumber == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() => _selectedDeliveryNumber = null),
                              ),
                      ),
                      child: Text(_selectedDeliveryNumber?.deliveryNo ?? 'All Deliveries'),
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
              child: FilledButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Print'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _print,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final rows = _rows!;
    if (rows.isEmpty) return const Center(child: Text('No deliveries found for this period.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Card(
            child: ListTile(
              title: Text(row.customerName),
              subtitle: Text(
                '${row.deliveryNo}  |  ${_dateFormat.format(row.deliveryDate)}\n'
                '${row.driverName}${row.vehicleNumber != null ? ' • ${row.vehicleNumber}' : ''}  •  ${row.lineCount} item${row.lineCount == 1 ? '' : 's'}',
              ),
              isThreeLine: true,
              trailing: Text(row.totalQty.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DeliveryDetailScreen(deliveryNo: row.deliveryNo)),
              ),
            ),
          ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_totalQty.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
