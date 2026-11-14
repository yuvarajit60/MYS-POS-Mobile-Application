import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/app_theme.dart';
import '../../core/company_provider.dart';
import '../../core/report_pdf_builder.dart';
import '../../models/customer.dart';
import '../../models/ledger_all_customers_row.dart';
import '../../models/ledger_entry.dart';
import '../../services/customer_service.dart';
import '../../services/ledger_service.dart';
import '../widgets/web_search_picker.dart';

/// Web equivalent of ledger_report_screen.dart (mobile) — same running
/// Outstanding Amount balance per transaction (see
/// SP_MOBILE_GET_CUSTOMER_LEDGER) and the same all-customers summary when
/// no customer is picked, presented as data tables.
class LedgerReportWebScreen extends StatefulWidget {
  const LedgerReportWebScreen({super.key});

  @override
  State<LedgerReportWebScreen> createState() => _LedgerReportWebScreenState();
}

class _LedgerReportWebScreenState extends State<LedgerReportWebScreen> {
  final _customerService = CustomerService();
  final _ledgerService = LedgerService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');
  static final _amountFormat = NumberFormat('#,##0.00');

  Customer? _selectedCustomer;
  DateTime? _fromDate;
  DateTime? _toDate;

  bool _loading = false;
  String? _error;
  List<LedgerEntry>? _rows;
  List<LedgerAllCustomersRow>? _allRows;

  Future<void> _pickCustomer() async {
    final customer = await showWebSearchPicker<Customer>(
      context: context,
      title: 'Search customer (leave blank for all)',
      search: _customerService.search,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
    );
    if (customer == null) return;
    setState(() {
      _selectedCustomer = customer;
      _rows = null;
      _allRows = null;
      _error = null;
    });
    _generate();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
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
      final customer = _selectedCustomer;
      if (customer == null) {
        final rows = await _ledgerService.getAllCustomers(fromDate: _fromDate, toDate: _toDate);
        if (!mounted) return;
        setState(() {
          _allRows = rows;
          _rows = null;
        });
      } else {
        final rows = await _ledgerService.getLedger(
          customerId: customer.customerId,
          fromDate: _fromDate,
          toDate: _toDate,
        );
        if (!mounted) return;
        setState(() {
          _rows = rows;
          _allRows = null;
        });
      }
    } on LedgerServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<dynamic> _buildDoc() {
    return _selectedCustomer == null
        ? ReportPdfBuilder.buildLedgerAllCustomers(
            rows: _allRows ?? [],
            company: CompanyProvider.instance.company,
            fromDate: _fromDate,
            toDate: _toDate,
          )
        : ReportPdfBuilder.buildLedgerSummary(
            rows: _rows ?? [],
            company: CompanyProvider.instance.company,
            customerName: _selectedCustomer?.customerName ?? '',
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
    await Printing.sharePdf(bytes: await doc.save(), filename: 'customer_ledger.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = (_rows?.isNotEmpty ?? false) || (_allRows?.isNotEmpty ?? false);
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: _pickCustomer,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Customer',
                              suffixIcon: _selectedCustomer == null
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => setState(() {
                                        _selectedCustomer = null;
                                        _rows = null;
                                        _allRows = null;
                                      }),
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
                                  decoration: InputDecoration(
                                    labelText: 'From Date',
                                    suffixIcon: _fromDate == null
                                        ? null
                                        : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _fromDate = null)),
                                  ),
                                  child: Text(_fromDate == null ? 'All' : _dateFormat.format(_fromDate!)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDate(isFrom: false),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'To Date',
                                    suffixIcon: _toDate == null
                                        ? null
                                        : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _toDate = null)),
                                  ),
                                  child: Text(_toDate == null ? 'All' : _dateFormat.format(_toDate!)),
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
                            if (hasResults) ...[
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
                if (_allRows != null) _buildAllCustomersResults(),
                if (_rows != null) _buildResults(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllCustomersResults() {
    final rows = _allRows!;
    if (rows.isEmpty) return const Center(child: Text('No transactions found for this period.'));

    final totalQty = rows.fold<double>(0, (sum, r) => sum + r.qty);
    final totalAmount = rows.fold<double>(0, (sum, r) => sum + r.totalAmount);
    final receivedAmount = rows.fold<double>(0, (sum, r) => sum + r.receivedAmount);
    final outstandingAmount = rows.fold<double>(0, (sum, r) => sum + r.outstandingAmount);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(MysColors.bgLight),
              columns: const [
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Qty'), numeric: true),
                DataColumn(label: Text('Total'), numeric: true),
                DataColumn(label: Text('Received'), numeric: true),
                DataColumn(label: Text('Outstanding'), numeric: true),
              ],
              rows: [
                for (final row in rows)
                  DataRow(cells: [
                    DataCell(Text(row.customerName)),
                    DataCell(Text(row.txnType)),
                    DataCell(Text(_amountFormat.format(row.qty))),
                    DataCell(Text(_amountFormat.format(row.totalAmount))),
                    DataCell(Text(_amountFormat.format(row.receivedAmount))),
                    DataCell(Text(_amountFormat.format(row.outstandingAmount), style: const TextStyle(fontWeight: FontWeight.w600))),
                  ]),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Report Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Qty ${_amountFormat.format(totalQty)}   Total ${_amountFormat.format(totalAmount)}   '
                  'Received ${_amountFormat.format(receivedAmount)}   Outstanding ${_amountFormat.format(outstandingAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
    if (rows.isEmpty) return const Center(child: Text('No transactions found for this customer.'));

    final closingBalance = rows.last.outstandingAmount;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(MysColors.bgLight),
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Txn No')),
                DataColumn(label: Text('Total'), numeric: true),
                DataColumn(label: Text('Received'), numeric: true),
                DataColumn(label: Text('Outstanding'), numeric: true),
              ],
              rows: [
                for (final row in rows)
                  DataRow(cells: [
                    DataCell(Text(_dateFormat.format(row.txnDate))),
                    DataCell(Text(row.txnType)),
                    DataCell(Text(row.txnNo)),
                    DataCell(Text(_amountFormat.format(row.totalAmount))),
                    DataCell(Text(_amountFormat.format(row.receivedAmount))),
                    DataCell(Text(_amountFormat.format(row.outstandingAmount), style: const TextStyle(fontWeight: FontWeight.w600))),
                  ]),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Outstanding Balance', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_amountFormat.format(closingBalance), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
