import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/app_theme.dart';
import '../../core/company_provider.dart';
import '../../core/report_pdf_builder.dart';
import '../../models/customer.dart';
import '../../models/driver.dart';
import '../../models/trip_entry_number.dart';
import '../../models/trip_entry_summary.dart';
import '../../screens/trip_entry_detail_screen.dart';
import '../../screens/trip_entry_graph_screen.dart';
import '../../services/customer_service.dart';
import '../../services/employee_service.dart';
import '../../services/trip_entry_report_service.dart';
import '../widgets/web_search_picker.dart';

/// Web equivalent of trip_entry_reports_screen.dart (mobile) — the Graph
/// view (TripEntryGraphScreen) is reused as-is via a normal page push.
class TripEntryReportWebScreen extends StatefulWidget {
  const TripEntryReportWebScreen({super.key});

  @override
  State<TripEntryReportWebScreen> createState() => _TripEntryReportWebScreenState();
}

class _TripEntryReportWebScreenState extends State<TripEntryReportWebScreen> {
  final _customerService = CustomerService();
  final _employeeService = EmployeeService();
  final _reportService = TripEntryReportService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');
  static final _amountFormat = NumberFormat('#,##0.00');

  Customer? _selectedCustomer;
  Driver? _selectedDriver;
  TripEntryNumber? _selectedEntryNumber;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  bool _loading = false;
  String? _error;
  List<TripEntrySummary>? _rows;

  double get _total => _rows?.fold<double>(0, (sum, r) => sum + r.netAmount) ?? 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _pickEntryNumber() async {
    final entryNumber = await showWebSearchPicker<TripEntryNumber>(
      context: context,
      title: 'Search trip entry no (leave blank for all)',
      search: _reportService.searchTripEntryNumbers,
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

  Future<void> _pickDriver() async {
    final driver = await showWebSearchPicker<Driver>(
      context: context,
      title: 'Search driver (leave blank for all)',
      search: _employeeService.searchDrivers,
      itemLabel: (d) => d.employeeName,
      itemSubtitle: (d) => d.mobileNo,
    );
    if (driver != null) setState(() => _selectedDriver = driver);
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
        driverId: _selectedDriver?.employeeId,
        tripEntryNo: _selectedEntryNumber?.entryNo,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } on TripEntryReportServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<dynamic> _buildDoc() {
    return ReportPdfBuilder.buildTripEntrySummary(
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
    await Printing.sharePdf(bytes: await doc.save(), filename: 'trip_entry_report.pdf');
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
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TripEntryGraphScreen())),
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
                              labelText: 'Trip Entry No',
                              suffixIcon: _selectedEntryNumber == null
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => setState(() => _selectedEntryNumber = null),
                                    ),
                            ),
                            child: Text(_selectedEntryNumber?.entryNo ?? 'All Trip Entries'),
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
                        InkWell(
                          onTap: _pickDriver,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Driver',
                              suffixIcon: _selectedDriver == null
                                  ? null
                                  : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _selectedDriver = null)),
                            ),
                            child: Text(_selectedDriver?.employeeName ?? 'All Drivers'),
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
    if (rows.isEmpty) return const Center(child: Text('No trip entries found for this period.'));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ...[
            for (final row in rows)
              ListTile(
                title: Text(row.customerName),
                subtitle: Text(
                  '${row.entryNo}  |  Entry: ${_dateFormat.format(row.entryDate)}  |  Trip: ${_dateFormat.format(row.tripDate)}\n'
                  '${row.siteName} • ${row.driverName}',
                ),
                isThreeLine: true,
                trailing: Text(_amountFormat.format(row.netAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TripEntryDetailScreen(tripEntryId: row.tripEntryId)),
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
