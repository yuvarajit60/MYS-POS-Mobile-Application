import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../models/graph_data_point.dart';
import '../../models/pending_sales_order_by_customer.dart';
import '../../services/report_service.dart';

/// The web app's landing page — a welcome/clock banner, the Sales Order
/// yearly (monthly-bucketed) bar chart already used by mobile's
/// GraphScreen, and a bar chart of pending (not yet delivered) Sales
/// Order quantity by customer (see IReportService.GetPendingByCustomerAsync,
/// same "pending" definition DeliveryService already uses).
class HomeWebScreen extends StatefulWidget {
  const HomeWebScreen({super.key});

  @override
  State<HomeWebScreen> createState() => _HomeWebScreenState();
}

class _HomeWebScreenState extends State<HomeWebScreen> {
  final _reportService = ReportService();
  static final _dateFormat = DateFormat('d MMM yyyy - EEEE');
  static final _timeFormat = DateFormat('hh:mm a');

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  bool _loadingYearly = true;
  List<GraphDataPoint> _yearlyPoints = [];

  bool _loadingPending = true;
  String? _pendingError;
  List<PendingSalesOrderByCustomer> _pendingRows = [];

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadYearlySales();
    _loadPendingByCustomer();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadYearlySales() async {
    try {
      final points = await _reportService.getGraphData(groupBy: 'month', year: DateTime.now().year);
      if (!mounted) return;
      setState(() {
        _yearlyPoints = points;
        _loadingYearly = false;
      });
    } on ReportServiceException {
      if (!mounted) return;
      setState(() => _loadingYearly = false);
    }
  }

  Future<void> _loadPendingByCustomer() async {
    try {
      final rows = await _reportService.getPendingByCustomer();
      if (!mounted) return;
      setState(() {
        _pendingRows = rows;
        _loadingPending = false;
      });
    } on ReportServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingError = e.message;
        _loadingPending = false;
      });
    }
  }

  String get _greeting {
    final hour = _now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_greeting, Welcome back',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: MysColors.green500),
                              ),
                              const SizedBox(height: 6),
                              Text(_dateFormat.format(_now), style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        Text(
                          _timeFormat.format(_now),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: MysColors.navy900),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Sales Order — ${DateTime.now().year}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 240,
                          child: _loadingYearly
                              ? const Center(child: CircularProgressIndicator())
                              : _yearlyPoints.every((p) => p.totalAmount == 0)
                                  ? const Center(child: Text('No sales orders yet this year.'))
                                  : _buildBarChart(
                                      values: [for (final p in _yearlyPoints) p.totalAmount],
                                      labels: [for (final p in _yearlyPoints) p.label],
                                      barColor: MysColors.green500,
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Pending Sales Orders (Not Yet Delivered) — By Customer',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 240,
                          child: _loadingPending
                              ? const Center(child: CircularProgressIndicator())
                              : _pendingError != null
                                  ? Center(child: Text(_pendingError!, style: const TextStyle(color: Colors.red)))
                                  : _pendingRows.isEmpty
                                      ? const Center(child: Text('No pending deliveries — everything is caught up.'))
                                      : _buildBarChart(
                                          values: [for (final r in _pendingRows) r.pendingQty],
                                          labels: [for (final r in _pendingRows) r.customerName],
                                          barColor: const Color(0xFFE17055),
                                        ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart({required List<double> values, required List<String> labels, required Color barColor}) {
    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    final maxY = maxValue <= 0 ? 100.0 : maxValue * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(_compactNumber(value), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[index],
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              rod.toY.toStringAsFixed(2),
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: barColor,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _compactNumber(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
