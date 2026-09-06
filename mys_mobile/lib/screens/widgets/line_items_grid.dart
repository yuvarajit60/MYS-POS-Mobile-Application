import 'package:flutter/material.dart';
import '../../models/sales_order_line.dart';

/// Read/edit grid for the sales-order line items. State (the list itself)
/// lives in the parent screen so the running total can be computed alongside
/// it — this widget just renders rows and reports qty/mrp/rate/delete
/// changes back up. MRP (tax-inclusive) and Rate (tax-exclusive) are both
/// editable and kept in sync — editing one recomputes the other from the
/// product's own GST%, so both fields need their own controller here (a
/// plain `initialValue` only seeds a field once and wouldn't reflect the
/// other field's edits). TotalAmount shown is tax-inclusive (rate x qty,
/// plus CGST + SGST).
class LineItemsGrid extends StatefulWidget {
  final List<SalesOrderLine> lines;
  final void Function(int index, double newQty) onQtyChanged;
  final void Function(int index, double newMrp) onMrpChanged;
  final void Function(int index, double newRate) onRateChanged;
  final void Function(int index) onDelete;

  const LineItemsGrid({
    super.key,
    required this.lines,
    required this.onQtyChanged,
    required this.onMrpChanged,
    required this.onRateChanged,
    required this.onDelete,
  });

  @override
  State<LineItemsGrid> createState() => _LineItemsGridState();
}

class _LineItemsGridState extends State<LineItemsGrid> {
  final Map<SalesOrderLine, TextEditingController> _mrpControllers = {};
  final Map<SalesOrderLine, TextEditingController> _rateControllers = {};

  String _formatMoney(double value) => value.toStringAsFixed(2);

  TextEditingController _controllerFor(
    Map<SalesOrderLine, TextEditingController> controllers,
    SalesOrderLine line,
    double Function(SalesOrderLine) valueOf,
  ) {
    final existing = controllers[line];
    if (existing != null) {
      if (double.tryParse(existing.text) != valueOf(line)) {
        existing.text = _formatMoney(valueOf(line));
      }
      return existing;
    }
    final controller = TextEditingController(text: _formatMoney(valueOf(line)));
    controllers[line] = controller;
    return controller;
  }

  void _disposeControllersFor(Iterable<SalesOrderLine> removed) {
    for (final line in removed) {
      _mrpControllers.remove(line)?.dispose();
      _rateControllers.remove(line)?.dispose();
    }
  }

  @override
  void didUpdateWidget(covariant LineItemsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.lines.toSet();
    _disposeControllersFor(_mrpControllers.keys.where((l) => !current.contains(l)).toList());
  }

  @override
  void dispose() {
    for (final controller in _mrpControllers.values) {
      controller.dispose();
    }
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _controllerFor(_mrpControllers, line, (l) => l.mrp),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(isDense: true, labelText: 'MRP'),
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null && parsed >= 0) widget.onMrpChanged(index, parsed);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: _controllerFor(_rateControllers, line, (l) => l.rate),
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
                      key: ValueKey('qty-${line.product.productId}-$index'),
                      initialValue: line.qty == line.qty.roundToDouble() ? line.qty.toInt().toString() : line.qty.toString(),
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
