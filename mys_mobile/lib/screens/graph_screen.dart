import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/graph_data_point.dart';
import '../services/report_service.dart';

enum _GraphGroupBy { month, year }

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final _reportService = ReportService();

  _GraphGroupBy _groupBy = _GraphGroupBy.month;
  int _year = DateTime.now().year;

  bool _loading = true;
  String? _error;
  List<GraphDataPoint> _points = [];

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
      final points = await _reportService.getGraphData(
        groupBy: _groupBy == _GraphGroupBy.month ? 'month' : 'year',
        year: _groupBy == _GraphGroupBy.month ? _year : null,
      );
      if (!mounted) return;
      setState(() => _points = points);
    } on ReportServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _maxValue {
    final max = _points.fold<double>(0, (m, p) => p.totalAmount > m ? p.totalAmount : m);
    return max <= 0 ? 100 : max * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Order Graph')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_GraphGroupBy>(
              segments: const [
                ButtonSegment(value: _GraphGroupBy.month, label: Text('Monthly')),
                ButtonSegment(value: _GraphGroupBy.year, label: Text('Yearly')),
              ],
              selected: {_groupBy},
              onSelectionChanged: (selection) {
                setState(() => _groupBy = selection.first);
                _load();
              },
            ),
            if (_groupBy == _GraphGroupBy.month) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Year:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _year,
                    items: [for (var y = currentYear; y >= currentYear - 5; y--) DropdownMenuItem(value: y, child: Text('$y'))],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _year = value);
                      _load();
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : _points.every((p) => p.totalAmount == 0)
                          ? const Center(child: Text('No sales data for this period.'))
                          : _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    return BarChart(
      BarChartData(
        maxY: _maxValue,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 48, getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox.shrink();
              return Text(_compactNumber(value), style: const TextStyle(fontSize: 10));
            }),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_points[index].label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
          for (var i = 0; i < _points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _points[i].totalAmount,
                  color: AmselColors.gold,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
