import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/company_provider.dart';
import '../core/report_pdf_builder.dart';
import '../models/delivery_detail.dart';
import '../services/delivery_report_service.dart';

/// Drill-down from a Summary row on the Delivery Report screen — shows all
/// lines saved together under one DeliveryNo. Mirrors TripEntryDetailScreen.
class DeliveryDetailScreen extends StatefulWidget {
  final String deliveryNo;
  const DeliveryDetailScreen({super.key, required this.deliveryNo});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  final _reportService = DeliveryReportService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

  bool _loading = true;
  String? _error;
  DeliveryDetail? _delivery;

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
      final delivery = await _reportService.getDeliveryDetail(widget.deliveryNo);
      if (!mounted) return;
      setState(() => _delivery = delivery);
    } on DeliveryReportServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _print() async {
    final doc = await ReportPdfBuilder.buildDeliveryDetail(delivery: _delivery!, company: CompanyProvider.instance.company);
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_delivery?.deliveryNo ?? 'Delivery')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildContent(_delivery!),
      bottomNavigationBar: _delivery == null
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

  Widget _buildContent(DeliveryDetail delivery) {
    final totalQty = delivery.lines.fold<double>(0, (sum, l) => sum + l.deliveryQty);

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
                  Text(delivery.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  if (delivery.driverName.isNotEmpty) Text('Driver: ${delivery.driverName}'),
                  if (delivery.vehicleNumber != null) Text('Vehicle: ${delivery.vehicleNumber}'),
                  const SizedBox(height: 8),
                  Text('Delivery No: ${delivery.deliveryNo}'),
                  Text('Date: ${_dateFormat.format(delivery.deliveryDate)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Products', style: Theme.of(context).textTheme.titleMedium),
          for (final line in delivery.lines)
            Card(
              child: ListTile(
                title: Text(line.productName),
                subtitle: Text('Sales Order: ${line.salesOrderNo}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(line.deliveryQty.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('Bal: ${line.balanceQty.toStringAsFixed(0)}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Qty', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(totalQty.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
