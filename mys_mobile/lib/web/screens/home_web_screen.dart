import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../services/report_service.dart';

/// The web app's landing page — quick-launch tiles into each of the three
/// sidebar sections, plus a this-week sales snapshot. The three callbacks
/// let WebAppShell decide exactly which screen each tile opens, without
/// this widget knowing about _WebSection (kept private to web_app_shell.dart).
class HomeWebScreen extends StatefulWidget {
  final VoidCallback onOpenMasters;
  final VoidCallback onOpenEntries;
  final VoidCallback onOpenReports;

  const HomeWebScreen({
    super.key,
    required this.onOpenMasters,
    required this.onOpenEntries,
    required this.onOpenReports,
  });

  @override
  State<HomeWebScreen> createState() => _HomeWebScreenState();
}

class _HomeWebScreenState extends State<HomeWebScreen> {
  final _reportService = ReportService();
  static final _dayLabelFormat = DateFormat('EEE');
  static final _dateFormat = DateFormat('d MMM');

  bool _loading = true;
  List<double> _dailyTotals = List.filled(7, 0);
  List<String> _dayLabels = List.filled(7, '');

  @override
  void initState() {
    super.initState();
    _loadWeeklySales();
  }

  Future<void> _loadWeeklySales() async {
    final today = DateTime.now();
    final fromDate = today.subtract(const Duration(days: 6));
    try {
      final rows = await _reportService.getSummary(fromDate: fromDate, toDate: today);
      if (!mounted) return;
      final totals = List<double>.filled(7, 0);
      final labels = List<String>.filled(7, '');
      for (var i = 0; i < 7; i++) {
        final day = fromDate.add(Duration(days: i));
        labels[i] = _dayLabelFormat.format(day);
      }
      for (final row in rows) {
        final offset = row.entryDate.difference(DateTime(fromDate.year, fromDate.month, fromDate.day)).inDays;
        if (offset >= 0 && offset < 7) totals[offset] += row.netAmount;
      }
      setState(() {
        _dailyTotals = totals;
        _dayLabels = labels;
        _loading = false;
      });
    } on ReportServiceException {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      color: MysColors.bgLight,
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _InfoCard(
                        label: _greeting.toUpperCase(),
                        value: Session.instance.isDriver ? 'Driver' : 'Welcome back',
                        color: MysColors.green500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InfoCard(label: 'DATE', value: _dateFormat.format(now), color: MysColors.navy900),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _SectionTile(
                        icon: Icons.inventory_2_outlined,
                        title: 'Masters',
                        subtitle: 'Products, customers, sites and more.',
                        color: const Color(0xFF6C5CE7),
                        onTap: widget.onOpenMasters,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SectionTile(
                        icon: Icons.edit_note,
                        title: 'Entries',
                        subtitle: 'Sales orders, deliveries, trips and payments.',
                        color: const Color(0xFF00B894),
                        onTap: widget.onOpenEntries,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SectionTile(
                        icon: Icons.bar_chart,
                        title: 'Reports',
                        subtitle: 'Sales, ledger, payments and more.',
                        color: const Color(0xFF0984E3),
                        onTap: widget.onOpenReports,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('This Week\'s Sales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 240,
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _dailyTotals.every((v) => v == 0)
                                  ? const Center(child: Text('No sales orders in the last 7 days.'))
                                  : _buildChart(),
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

  Widget _buildChart() {
    final maxValue = _dailyTotals.fold<double>(0, (m, v) => v > m ? v : m);
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
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _dayLabels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_dayLabels[index], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
          for (var i = 0; i < _dailyTotals.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _dailyTotals[i],
                  color: MysColors.green500,
                  width: 28,
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

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
