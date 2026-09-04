import 'package:flutter/material.dart';
import '../../models/sales_order_line.dart';

/// Read/edit grid for the sales-order line items. State (the list itself)
/// lives in the parent screen so the running total can be computed alongside
/// it — this widget just renders rows and reports rate/qty/delete changes
/// back up. MRP is shown read-only for reference; Rate defaults to the
/// tax-exclusive price backed out of that MRP but is editable per line.
/// TotalAmount shown is tax-inclusive (rate x qty, plus CGST + SGST).
class LineItemsGrid extends StatelessWidget {
  final List<SalesOrderLine> lines;
  final void Function(int index, double newQty) onQtyChanged;
  final void Function(int index, double newRate) onRateChanged;
  final void Function(int index) onDelete;

  const LineItemsGrid({
    super.key,
    required this.lines,
    required this.onQtyChanged,
    required this.onRateChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No products added yet.')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lines.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final line = lines[index];
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
                    onPressed: () => onDelete(index),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: InputDecorator(
                      decoration: const InputDecoration(isDense: true, labelText: 'MRP'),
                      child: Text(line.mrp.toStringAsFixed(2)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      key: ValueKey('rate-${line.product.productId}-$index'),
                      initialValue: line.rate.toStringAsFixed(2),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(isDense: true, labelText: 'Rate'),
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null && parsed >= 0) onRateChanged(index, parsed);
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
                        if (parsed != null && parsed > 0) onQtyChanged(index, parsed);
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
