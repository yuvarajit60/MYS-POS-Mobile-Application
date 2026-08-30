import 'package:flutter/material.dart';
import '../../models/delivery_line.dart';

/// Read/edit grid for pending Sales Order lines in Delivery Entry. Only
/// CurrentDelivery is editable — everything else (SalesQty/DeliveryQty/
/// BalanceQty) is a read-only snapshot. CurrentDelivery is clamped to
/// [0, balanceQty] here in the UI; the server re-validates authoritatively
/// since this entry can't be edited or corrected after saving.
class DeliveryLineItemsGrid extends StatelessWidget {
  final List<DeliveryLine> lines;
  final void Function(int index, double newCurrentDelivery) onCurrentDeliveryChanged;

  const DeliveryLineItemsGrid({
    super.key,
    required this.lines,
    required this.onCurrentDeliveryChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No pending deliveries for this customer.')),
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
              Text(line.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Sales Order: ${line.salesOrderNo}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _stat('Sales Qty', line.salesQty),
                  _stat('Delivered', line.deliveryQty),
                  _stat('Balance', line.balanceQty),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 140,
                child: TextFormField(
                  key: ValueKey('current-delivery-${line.salesOrderDetId}'),
                  initialValue: line.currentDelivery == 0 ? '' : _formatQty(line.currentDelivery),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(isDense: true, labelText: 'Current Delivery', border: OutlineInputBorder()),
                  onChanged: (value) {
                    final parsed = double.tryParse(value) ?? 0;
                    final clamped = parsed < 0 ? 0.0 : (parsed > line.balanceQty ? line.balanceQty : parsed);
                    onCurrentDeliveryChanged(index, clamped);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatQty(double qty) => qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();

  Widget _stat(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(_formatQty(value), style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
