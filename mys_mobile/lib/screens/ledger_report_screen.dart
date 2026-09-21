import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/company_provider.dart';
import '../core/report_pdf_builder.dart';
import '../models/customer.dart';
import '../models/ledger_entry.dart';
import '../services/ledger_service.dart';
import '../services/payment_service.dart';
import 'widgets/search_picker_sheet.dart';

/// Customer ledger — a running Delivery/Payment statement with an
/// Outstanding Amount balance, derived from DELIVERY_DETAILS +
/// PAYMENT_DETAILS (see SP_MOBILE_GET_CUSTOMER_LEDGER). Customer is
/// required; the date range only narrows which rows are shown — the
/// running balance on each row still reflects the customer's entire
/// history, not just the filtered window (see LedgerService).
class LedgerReportScreen extends StatefulWidget {
  const LedgerReportScreen({super.key});

  @override
  State<LedgerReportScreen> createState() => _LedgerReportScreenState();
}

class _LedgerReportScreenState extends State<LedgerReportScreen> {
  final _paymentService = PaymentService();
  final _ledgerService = LedgerService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

  Customer? _selectedCustomer;
  DateTime? _fromDate;
  DateTime? _toDate;

  bool _loading = false;
  String? _error;
  List<LedgerEntry>? _rows;

  Future<void> _pickCustomer() async {
    final customer = await showSearchPicker<Customer>(
      context: context,
      title: 'Search customer',
      search: _paymentService.searchDeliveredCustomers,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
    );
    if (customer == null) return;
    setState(() {
      _selectedCustomer = customer;
      _rows = null;
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
    if (_selectedCustomer == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _ledgerService.getLedger(
        customerId: _selectedCustomer!.customerId,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } on LedgerServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _print() async {
    final doc = await ReportPdfBuilder.buildLedgerSummary(
      rows: _rows ?? [],
      company: CompanyProvider.instance.company,
      customerName: _selectedCustomer?.customerName ?? '',
      fromDate: _fromDate,
      toDate: _toDate,
    );
    await Printing.layoutPdf(onLayout: (format) => doc.save());
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
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Customer'),
                      child: Text(_selectedCustomer?.customerName ?? 'Tap to select a customer'),
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
                    onPressed: (_loading || _selectedCustomer == null) ? null : _generate,
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
                  row.txnType == 'Payment' ? Icons.arrow_downward : Icons.local_shipping_outlined,
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
