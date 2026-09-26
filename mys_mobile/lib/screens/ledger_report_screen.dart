import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/company_provider.dart';
import '../core/report_pdf_builder.dart';
import '../models/customer.dart';
import '../models/ledger_all_customers_row.dart';
import '../models/ledger_entry.dart';
import '../services/customer_service.dart';
import '../services/ledger_service.dart';
import 'widgets/search_picker_sheet.dart';

/// Customer ledger — a running Delivery/Trip Entry/Payment statement with an
/// Outstanding Amount balance (see SP_MOBILE_GET_CUSTOMER_LEDGER). The date
/// range only narrows which rows are shown — the running balance on each
/// row still reflects the customer's entire history, not just the filtered
/// window (see LedgerService).
///
/// Customer is optional: leaving it blank shows a flat register of every
/// transaction across every customer for the period (Tally "Ledger
/// Vouchers"-style — Customer/Type/Qty/Total/Received/Outstanding, with a
/// Report Totals footer) instead of one customer's running ledger.
class LedgerReportScreen extends StatefulWidget {
  const LedgerReportScreen({super.key});

  @override
  State<LedgerReportScreen> createState() => _LedgerReportScreenState();
}

class _LedgerReportScreenState extends State<LedgerReportScreen> {
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
    final customer = await showSearchPicker<Customer>(
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
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Ledger')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                              border: const OutlineInputBorder(),
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
                              border: const OutlineInputBorder(),
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
                  FilledButton(
                    onPressed: _loading ? null : _generate,
                    child: _loading ? const CircularProgressIndicator() : const Text('Generate Report'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  if (_allRows != null) _buildAllCustomersResults(),
                  if (_rows != null) _buildResults(),
                ],
              ),
            ),
          ),
          if ((_rows?.isNotEmpty ?? false) || (_allRows?.isNotEmpty ?? false))
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

  Widget _kv(String label, String value, {bool bold = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      );

  Widget _buildAllCustomersResults() {
    final rows = _allRows!;
    if (rows.isEmpty) return const Center(child: Text('No transactions found for this period.'));

    final totalQty = rows.fold<double>(0, (sum, r) => sum + r.qty);
    final totalAmount = rows.fold<double>(0, (sum, r) => sum + r.totalAmount);
    final receivedAmount = rows.fold<double>(0, (sum, r) => sum + r.receivedAmount);
    final outstandingAmount = rows.fold<double>(0, (sum, r) => sum + r.outstandingAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(row.customerName, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(_dateFormat.format(row.txnDate), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  Text('${row.txnType}  •  ${row.txnNo}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _kv('Qty', _amountFormat.format(row.qty))),
                      Expanded(child: _kv('Total', _amountFormat.format(row.totalAmount))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _kv('Received', _amountFormat.format(row.receivedAmount))),
                      Expanded(child: _kv('Outstanding', _amountFormat.format(row.outstandingAmount), bold: true)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const Divider(),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Report Total', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _kv('Qty', _amountFormat.format(totalQty), bold: true)),
                    Expanded(child: _kv('Total', _amountFormat.format(totalAmount), bold: true)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _kv('Received', _amountFormat.format(receivedAmount), bold: true)),
                    Expanded(child: _kv('Outstanding', _amountFormat.format(outstandingAmount), bold: true)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final rows = _rows!;
    if (rows.isEmpty) return const Center(child: Text('No transactions found for this customer.'));

    final closingBalance = rows.last.outstandingAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: row.txnType == 'Payment' ? Colors.green.shade100 : Colors.orange.shade100,
                child: Icon(
                  row.txnType == 'Payment'
                      ? Icons.arrow_downward
                      : row.txnType == 'Trip Entry'
                          ? Icons.local_shipping_outlined
                          : Icons.local_shipping,
                  color: row.txnType == 'Payment' ? Colors.green.shade800 : Colors.orange.shade800,
                  size: 20,
                ),
              ),
              title: Text('${row.txnType}  •  ${row.txnNo}'),
              subtitle: Text(
                '${_dateFormat.format(row.txnDate)}\n'
                'Total: ${row.totalAmount.toStringAsFixed(2)}   Received: ${row.receivedAmount.toStringAsFixed(2)}',
              ),
              isThreeLine: true,
              trailing: Text(
                row.outstandingAmount.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Outstanding Balance', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(closingBalance.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
