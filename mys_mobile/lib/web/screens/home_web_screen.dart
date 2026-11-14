import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../models/graph_data_point.dart';
import '../../services/delivery_report_service.dart';
import '../../services/report_service.dart';
import '../../services/trip_entry_report_service.dart';

/// Dimension a two-dimensional report tile (Pending Sales Order, Delivery)
/// can be viewed by, switched with a small toggle above the chart.
enum _ByDimension { customer, product }

/// The web app's landing page — a welcome/clock banner plus four graph
/// tiles: Sales Order (by month), Pending Sales Order, Delivery and Trip
/// (the last two switchable between customer-wise and product-wise via
/// _ByDimension). All four render through the same _buildBarChart so they
/// share one visual style.
class HomeWebScreen extends StatefulWidget {
  const HomeWebScreen({super.key});

  @override
  State<HomeWebScreen> createState() => _HomeWebScreenState();
}

class _HomeWebScreenState extends State<HomeWebScreen> {
  final _reportService = ReportService();
  final _deliveryReportService = DeliveryReportService();
  final _tripEntryReportService = TripEntryReportService();
  static final _dateFormat = DateFormat('d MMM yyyy - EEEE');
  static final _timeFormat = DateFormat('hh:mm a');

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  bool _loadingSales = true;
  List<GraphDataPoint> _salesPoints = [];

  bool _loadingPending = true;
  String? _pendingError;
  List<GraphDataPoint> _pendingByCustomer = [];
  List<GraphDataPoint> _pendingByProduct = [];
  _ByDimension _pendingView = _ByDimension.customer;

  bool _loadingDelivery = true;
  String? _deliveryError;
  List<GraphDataPoint> _deliveryByCustomer = [];
  List<GraphDataPoint> _deliveryByProduct = [];
  _ByDimension _deliveryView = _ByDimension.customer;

  bool _loadingTrip = true;
  String? _tripError;
  List<GraphDataPoint> _tripByCustomer = [];

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadSales();
    _loadPending();
    _loadDelivery();
    _loadTrip();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSales() async {
    try {
      final points = await _reportService.getGraphData(groupBy: 'month', year: DateTime.now().year);
      if (!mounted) return;
      setState(() {
        _salesPoints = points;
        _loadingSales = false;
      });
    } on ReportServiceException {
      if (!mounted) return;
      setState(() => _loadingSales = false);
    }
  }

  Future<void> _loadPending() async {
    try {
      final customerRows = await _reportService.getPendingByCustomer();
      final productPoints = await _reportService.getPendingByProduct();
      if (!mounted) return;
      setState(() {
        _pendingByCustomer = [for (final r in customerRows) GraphDataPoint(label: r.customerName, totalAmount: r.pendingQty)];
        _pendingByProduct = productPoints;
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

  Future<void> _loadDelivery() async {
    try {
      final results = await Future.wait([_deliveryReportService.getByCustomer(), _deliveryReportService.getByProduct()]);
      if (!mounted) return;
      setState(() {
        _deliveryByCustomer = results[0];
        _deliveryByProduct = results[1];
        _loadingDelivery = false;
      });
    } on DeliveryReportServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _deliveryError = e.message;
        _loadingDelivery = false;
      });
    }
  }

  Future<void> _loadTrip() async {
    try {
      final rows = await _tripEntryReportService.getByCustomer();
      if (!mounted) return;
      setState(() {
        _tripByCustomer = rows;
        _loadingTrip = false;
      });
    } on TripEntryReportServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _tripError = e.message;
        _loadingTrip = false;
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
                _buildGreetingCard(),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 900;
                    final tiles = [
                      _buildSalesTile(),
                      _buildPendingTile(),
                      _buildDeliveryTile(),
                      _buildTripTile(),
                    ];
                    if (isNarrow) {
                      return Column(
                        children: [for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: 20), child: t)],
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: tiles[0]),
                            const SizedBox(width: 20),
                            Expanded(child: tiles[1]),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: tiles[2]),
                            const SizedBox(width: 20),
                            Expanded(child: tiles[3]),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    return Card(
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
    );
  }

  Widget _buildSalesTile() {
    return _GraphCard(
      title: 'Sales Order — ${DateTime.now().year}',
      loading: _loadingSales,
      error: null,
      empty: _salesPoints.every((p) => p.totalAmount == 0) ? 'No sales orders yet this year.' : null,
      child: _buildBarChart(
        values: [for (final p in _salesPoints) p.totalAmount],
        labels: [for (final p in _salesPoints) p.label],
        barColor: MysColors.green500,
        valuePrefix: '₹',
      ),
    );
  }

  Widget _buildPendingTile() {
    final points = _pendingView == _ByDimension.customer ? _pendingByCustomer : _pendingByProduct;
    return _GraphCard(
      title: 'Pending Sales Orders — Total Qty',
      loading: _loadingPending,
      error: _pendingError,
      empty: points.isEmpty ? 'No pending deliveries — everything is caught up.' : null,
      toggle: _DimensionToggle(
        value: _pendingView,
        onChanged: (v) => setState(() => _pendingView = v),
      ),
      child: _buildBarChart(
        values: [for (final p in points) p.totalAmount],
        labels: [for (final p in points) p.label],
        barColor: const Color(0xFFE17055),
      ),
    );
  }

  Widget _buildDeliveryTile() {
    final points = _deliveryView == _ByDimension.customer ? _deliveryByCustomer : _deliveryByProduct;
    return _GraphCard(
      title: 'Delivery — ${DateTime.now().year} — Total Qty',
      loading: _loadingDelivery,
      error: _deliveryError,
      empty: points.isEmpty ? 'No deliveries yet this year.' : null,
      toggle: _DimensionToggle(
        value: _deliveryView,
        onChanged: (v) => setState(() => _deliveryView = v),
      ),
      child: _buildBarChart(
        values: [for (final p in points) p.totalAmount],
        labels: [for (final p in points) p.label],
        barColor: MysColors.navy900,
      ),
    );
  }

  Widget _buildTripTile() {
    return _GraphCard(
      title: 'Trip Entry — ${DateTime.now().year} — By Customer',
      loading: _loadingTrip,
      error: _tripError,
      empty: _tripByCustomer.isEmpty ? 'No trip entries yet this year.' : null,
      child: _buildBarChart(
        values: [for (final p in _tripByCustomer) p.totalAmount],
        labels: [for (final p in _tripByCustomer) p.label],
        barColor: const Color(0xFF6C5CE7),
        valuePrefix: '₹',
      ),
    );
  }

  Widget _buildBarChart({
    required List<double> values,
    required List<String> labels,
    required Color barColor,
    String valuePrefix = '',
  }) {
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
                return Text('$valuePrefix${_compactNumber(value)}', style: const TextStyle(fontSize: 10));
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
              '$valuePrefix${rod.toY.toStringAsFixed(2)}',
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

/// Small "By Customer / By Product" segmented switch shown above a tile's
/// chart when that report has two dimensions to flip between.
class _DimensionToggle extends StatelessWidget {
  final _ByDimension value;
  final ValueChanged<_ByDimension> onChanged;
  const _DimensionToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_ByDimension>(
      segments: const [
        ButtonSegment(value: _ByDimension.customer, label: Text('By Customer')),
        ButtonSegment(value: _ByDimension.product, label: Text('By Product')),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

/// One dashboard tile: title (+ optional dimension toggle) above a fixed
/// height area that shows a loading spinner, an error, an empty-state
/// message, or the chart itself.
class _GraphCard extends StatelessWidget {
  final String title;
  final bool loading;
  final String? error;
  final String? empty;
  final Widget child;
  final Widget? toggle;

  const _GraphCard({
    required this.title,
    required this.loading,
    required this.error,
    required this.empty,
    required this.child,
    this.toggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                ?toggle,
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
                      : empty != null
                          ? Center(child: Text(empty!))
                          : child,
            ),
          ],
        ),
      ),
    );
  }
}
