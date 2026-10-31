import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/company_provider.dart';
import '../core/report_pdf_builder.dart';
import '../models/income_expense_entry_number.dart';
import '../models/income_expense_summary.dart';
import '../services/income_expense_report_service.dart';
import 'widgets/search_picker_sheet.dart';

/// Flat list of dbo.INCOMEOREXPENSES rows — mirrors the desktop app's own
/// "Income And Expense Document" report (Entry No/Date/Time/Type/
/// Particulars/Amount, Grand Total = sum of every row regardless of
/// Income vs Expenses). No line items on this table, so no drill-down
/// detail screen, same as Payment Report.
class IncomeExpenseReportScreen extends StatefulWidget {
  const IncomeExpenseReportScreen({super.key});

  @override
  State<IncomeExpenseReportScreen> createState() => _IncomeExpenseReportScreenState();
}

class _IncomeExpenseReportScreenState extends State<IncomeExpenseReportScreen> {
  final _reportService = IncomeExpenseReportService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');
  static final _timeFormat = DateFormat('hh:mm a');

  IncomeExpenseEntryNumber? _selectedEntryNumber;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  bool _loading = false;
  String? _error;
  List<IncomeExpenseSummary>? _rows;

  double get _total => _rows?.fold<double>(0, (sum, r) => sum + r.amount) ?? 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _pickEntryNumber() async {
    final entryNumber = await showSearchPicker<IncomeExpenseEntryNumber>(
      context: context,
      title: 'Search entry no (leave blank for all)',
      search: _reportService.searchEntryNumbers,
      itemLabel: (e) => e.entryNo,
    );
    if (entryNumber != null) setState(() => _selectedEntryNumber = entryNumber);
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
        entryNo: _selectedEntryNumber?.entryNo,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } on IncomeExpenseReportServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<dynamic> _buildDoc() {
    return ReportPdfBuilder.buildIncomeExpenseSummary(
      rows: _rows ?? [],
      company: CompanyProvider.instance.company,
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
    await Printing.sharePdf(bytes: await doc.save(), filename: 'income_expense_report.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Income and Expenses Report')),
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
                        labelText: 'Entry No',
                        suffixIcon: _selectedEntryNumber == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() => _selectedEntryNumber = null),
                              ),
                      ),
                      child: Text(_selectedEntryNumber?.entryNo ?? 'All Entries'),
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
    if (rows.isEmpty) return const Center(child: Text('No entries found for this period.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: row.incomeOrExpenses == 'Income' ? Colors.green.shade100 : Colors.red.shade100,
                child: Icon(
                  row.incomeOrExpenses == 'Income' ? Icons.arrow_downward : Icons.arrow_upward,
                  color: row.incomeOrExpenses == 'Income' ? Colors.green.shade800 : Colors.red.shade800,
                  size: 20,
                ),
              ),
              title: Text(row.particulars.isEmpty ? row.entryNo : row.particulars),
              subtitle: Text(
                '${row.entryNo}  |  ${row.incomeOrExpenses}\n'
                '${_dateFormat.format(row.entryDate)}  ${_timeFormat.format(row.entryTime)}',
              ),
              isThreeLine: true,
              trailing: Text(row.amount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600)),
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
