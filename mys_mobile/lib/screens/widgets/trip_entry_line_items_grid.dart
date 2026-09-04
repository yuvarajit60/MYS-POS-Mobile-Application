import 'package:flutter/material.dart';
import '../../models/trip_entry_line.dart';

/// Read/edit grid for trip-entry line items. Mirrors LineItemsGrid's
/// parent-owns-the-list pattern, but each row also has a Meter/Hours toggle
/// (not from a table — see TripEntryLine) that switches which pair of
/// fields is enabled, per the desktop Trip Entry screen's behavior.
class TripEntryLineItemsGrid extends StatefulWidget {
  final List<TripEntryLine> lines;
  final void Function(int index, MeterOrHours value) onMeterOrHoursChanged;
  final void Function(int index, DateTime value) onTimeStartChanged;
  final void Function(int index, DateTime value) onTimeCloseChanged;
  final void Function(int index, double value) onMeterStartChanged;
  final void Function(int index, double value) onMeterCloseChanged;
  final void Function(int index, double newQty) onQtyChanged;
  final void Function(int index, double newRate) onRateChanged;
  final void Function(int index) onDelete;

  const TripEntryLineItemsGrid({
    super.key,
    required this.lines,
    required this.onMeterOrHoursChanged,
    required this.onTimeStartChanged,
    required this.onTimeCloseChanged,
    required this.onMeterStartChanged,
    required this.onMeterCloseChanged,
    required this.onQtyChanged,
    required this.onRateChanged,
    required this.onDelete,
  });

  @override
  State<TripEntryLineItemsGrid> createState() => _TripEntryLineItemsGridState();
}

/// Qty can change from two sources: the rep typing in the field, or the
/// parent auto-computing it from Time/Meter start-close. TextFormField's
/// `initialValue` only seeds the field once, so a controller is needed to
/// reflect the auto-computed value — but the controller's text is only
/// force-updated when it doesn't already match the line's qty, so it never
/// clobbers the rep mid-keystroke.
class _TripEntryLineItemsGridState extends State<TripEntryLineItemsGrid> {
  final Map<TripEntryLine, TextEditingController> _qtyControllers = {};

  // Capped at 2 decimal places — Qty is usually already rounded to 2dp at
  // the source (see _recomputeQty), but this stays defensive in case a
  // division ever produces a longer repeating decimal (e.g. 2.3666666...).
  String _formatQty(double qty) => qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);

  TextEditingController _qtyControllerFor(TripEntryLine line) {
    final existing = _qtyControllers[line];
    if (existing != null) {
      if (double.tryParse(existing.text) != line.qty) {
        existing.text = _formatQty(line.qty);
      }
      return existing;
    }
    final controller = TextEditingController(text: _formatQty(line.qty));
    _qtyControllers[line] = controller;
    return controller;
  }

  void _disposeControllersFor(Iterable<TripEntryLine> removed) {
    for (final line in removed) {
      _qtyControllers.remove(line)?.dispose();
    }
  }

  @override
  void didUpdateWidget(covariant TripEntryLineItemsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.lines.toSet();
    _disposeControllersFor(_qtyControllers.keys.where((l) => !current.contains(l)).toList());
  }

  @override
  void dispose() {
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _meterDurationText(double meterStart, double meterClose) {
    final totalMinutes = ((meterClose - meterStart) * 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Tap to set';
    final d = value;
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDateTime(BuildContext context, DateTime? initial, ValueChanged<DateTime> onPicked) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return;
    onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No products added yet.')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.lines.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final line = widget.lines[index];
        final isHours = line.meterOrHours == MeterOrHours.hours;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(line.product.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => widget.onDelete(index),
                  ),
                ],
              ),
              SegmentedButton<MeterOrHours>(
                segments: const [
                  ButtonSegment(value: MeterOrHours.hours, label: Text('Hours')),
                  ButtonSegment(value: MeterOrHours.meter, label: Text('Meter')),
                ],
                selected: {line.meterOrHours},
                onSelectionChanged: (selection) => widget.onMeterOrHoursChanged(index, selection.first),
              ),
              const SizedBox(height: 8),
              if (isHours)
                Row(
                  children: [
                    Expanded(
                      child: _PickerField(
                        label: 'Time Start',
                        value: _formatDateTime(line.timeStart),
                        onTap: () => _pickDateTime(context, line.timeStart, (v) => widget.onTimeStartChanged(index, v)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerField(
                        label: 'Time Close',
                        value: _formatDateTime(line.timeClose),
                        onTap: () => _pickDateTime(context, line.timeClose, (v) => widget.onTimeCloseChanged(index, v)),
                      ),
                    ),
                  ],
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('meterstart-${line.product.productId}-$index'),
                        initialValue: line.meterStart?.toString() ?? '',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(isDense: true, labelText: 'Meter Start'),
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed != null) widget.onMeterStartChanged(index, parsed);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('meterclose-${line.product.productId}-$index'),
                        initialValue: line.meterClose?.toString() ?? '',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(isDense: true, labelText: 'Meter Close'),
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed != null) widget.onMeterCloseChanged(index, parsed);
                        },
                      ),
                    ),
                  ],
                ),
                if (line.meterStart != null && line.meterClose != null && line.meterClose! > line.meterStart!)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      // Meter readings are decimal hours (0.1 = 6 minutes), so
                      // this matches line.qty, which is just close - start.
                      'Duration: ${_meterDurationText(line.meterStart!, line.meterClose!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              if (line.vehicleName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Vehicle: ${line.vehicleName}', style: Theme.of(context).textTheme.bodySmall),
                ),
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      key: ValueKey('rate-${line.product.productId}-$index'),
                      initialValue: line.rate.toStringAsFixed(2),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(isDense: true, labelText: 'Rate'),
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null && parsed >= 0) widget.onRateChanged(index, parsed);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 70,
                    child: TextFormField(
                      controller: _qtyControllerFor(line),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(isDense: true, labelText: 'Qty'),
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null && parsed > 0) widget.onQtyChanged(index, parsed);
                      },
                    ),
                  ),
                  const Spacer(),
                  Text(
                    line.totalAmount.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(isDense: true, labelText: label, border: const OutlineInputBorder()),
        child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
