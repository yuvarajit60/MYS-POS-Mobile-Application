import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/company_provider.dart';
import '../core/report_pdf_builder.dart';
import '../models/trip_entry_detail.dart';
import '../models/trip_entry_line.dart';
import '../services/trip_entry_report_service.dart';

/// Drill-down from a Summary row on the Trip Entry Report screen — shows
/// one trip's full line items and lets the rep print just that invoice.
/// Mirrors OrderDetailScreen.
class TripEntryDetailScreen extends StatefulWidget {
  final int tripEntryId;
  const TripEntryDetailScreen({super.key, required this.tripEntryId});

  @override
  State<TripEntryDetailScreen> createState() => _TripEntryDetailScreenState();
}

class _TripEntryDetailScreenState extends State<TripEntryDetailScreen> {
  final _reportService = TripEntryReportService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');
  static final _dateTimeFormat = DateFormat('dd-MMM-yyyy HH:mm');

  bool _loading = true;
  String? _error;
  TripEntryDetail? _tripEntry;

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
      final tripEntry = await _reportService.getTripEntryDetail(widget.tripEntryId);
      if (!mounted) return;
      setState(() => _tripEntry = tripEntry);
    } on TripEntryReportServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _print() async {
    final doc = await ReportPdfBuilder.buildTripEntryDetail(tripEntry: _tripEntry!, company: CompanyProvider.instance.company);
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  String _lineSubtitle(TripEntryDetailLine line) {
    final usage = line.meterOrHours == MeterOrHours.hours
        ? 'Hours: ${line.timeStart != null ? _dateTimeFormat.format(line.timeStart!) : '-'} to ${line.timeClose != null ? _dateTimeFormat.format(line.timeClose!) : '-'}'
        : 'Meter: ${line.meterStart?.toStringAsFixed(1) ?? '-'} to ${line.meterClose?.toStringAsFixed(1) ?? '-'}';
    final vehicle = line.vehicleName != null ? '  |  Vehicle: ${line.vehicleName}' : '';
    return '$usage$vehicle\nQty: ${line.qty == line.qty.roundToDouble() ? line.qty.toInt() : line.qty} x ${line.rate.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tripEntry?.entryNo ?? 'Trip Entry')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildContent(_tripEntry!),
      bottomNavigationBar: _tripEntry == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Print'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _print,
              ),
            ),
    );
  }

  Widget _buildContent(TripEntryDetail tripEntry) {
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
                  Text(tripEntry.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  if (tripEntry.mobileNo.isNotEmpty) Text(tripEntry.mobileNo),
                  if (tripEntry.siteName.isNotEmpty) Text('Site: ${tripEntry.siteName}'),
                  if (tripEntry.driverName.isNotEmpty) Text('Driver: ${tripEntry.driverName}'),
                  const SizedBox(height: 8),
                  Text('Entry No: ${tripEntry.entryNo}'),
                  Text('Date: ${_dateFormat.format(tripEntry.entryDate)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Products', style: Theme.of(context).textTheme.titleMedium),
          for (final line in tripEntry.lines)
            Card(
              child: ListTile(
                title: Text(line.productName),
                subtitle: Text(_lineSubtitle(line)),
                isThreeLine: true,
                trailing: Text(line.taxableValue.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          const Divider(),
          _totalRow('Taxable Value', tripEntry.taxableValue),
          _totalRow('Total Tax', tripEntry.totalTax),
          _totalRow('Round Off', tripEntry.roundOff),
          const SizedBox(height: 4),
          _totalRow('Net Amount', tripEntry.netAmount, bold: true),
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
