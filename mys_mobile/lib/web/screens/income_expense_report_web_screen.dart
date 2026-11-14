import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/app_theme.dart';
import '../../core/company_provider.dart';
import '../../core/report_pdf_builder.dart';
import '../../models/income_expense_entry_number.dart';
import '../../models/income_expense_summary.dart';
import '../../services/income_expense_report_service.dart';
import '../widgets/web_search_picker.dart';

/// Web equivalent of income_expense_report_screen.dart (mobile) — same
/// running-balance-per-row + Net Total footer (see
/// IncomeExpenseReportService on the API side), presented as a data table
/// instead of a card list.
class IncomeExpenseReportWebScreen extends StatefulWidget {
  const IncomeExpenseReportWebScreen({super.key});

  @override
  State<IncomeExpenseReportWebScreen> createState() => _IncomeExpenseReportWebScreenState();
}

class _IncomeExpenseReportWebScreenState extends State<IncomeExpenseReportWebScreen> {
  final _reportService = IncomeExpenseReportService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');
  static final _timeFormat = DateFormat('hh:mm a');
  static final _amountFormat = NumberFormat('#,##0.00');

  IncomeExpenseEntryNumber? _selectedEntryNumber;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  bool _loading = false;
  String? _error;
  List<IncomeExpenseSummary>? _rows;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _pickEntryNumber() async {
    final entryNumber = await showWebSearchPicker<IncomeExpenseEntryNumber>(
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
                          onTap: _pickEntryNumber,
                          child: InputDecorator(
                            decoration: InputDecoration(
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
    if (rows.isEmpty) return const Center(child: Text('No entries found for this period.'));

    final netTotal = rows.first.runningBalance;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(MysColors.bgLight),
              columns: const [
                DataColumn(label: Text('Entry No')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Particulars')),
                DataColumn(label: Text('Amount'), numeric: true),
                DataColumn(label: Text('Balance'), numeric: true),
              ],
              rows: [
                for (final row in rows)
                  DataRow(cells: [
                    DataCell(Text(row.entryNo)),
                    DataCell(Text('${_dateFormat.format(row.entryDate)}\n${_timeFormat.format(row.entryTime)}')),
                    DataCell(_TypeBadge(incomeOrExpenses: row.incomeOrExpenses)),
                    DataCell(Text(row.particulars.isEmpty ? '-' : row.particulars)),
                    DataCell(Text(_amountFormat.format(row.amount))),
                    DataCell(Text(_amountFormat.format(row.runningBalance), style: const TextStyle(fontWeight: FontWeight.w600))),
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
                const Text('Net Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_amountFormat.format(netTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String incomeOrExpenses;
  const _TypeBadge({required this.incomeOrExpenses});

  @override
  Widget build(BuildContext context) {
    final isIncome = incomeOrExpenses == 'Income';
    final color = isIncome ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(20)),
      child: Text(incomeOrExpenses, style: TextStyle(color: color.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
