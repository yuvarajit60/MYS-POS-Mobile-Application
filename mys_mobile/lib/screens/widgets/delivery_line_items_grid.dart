import 'package:flutter/material.dart';
import '../../models/delivery_line.dart';

/// Read/edit grid for pending Sales Order lines in Delivery Entry. Only
/// CurrentDelivery is editable — everything else (SalesQty/DeliveryQty/
/// BalanceQty) is a read-only snapshot. CurrentDelivery is clamped to
/// [0, balanceQty] here in the UI (and the field itself is corrected to
/// show the clamped value, not just the underlying state) — the server
/// re-validates authoritatively since this entry can't be edited or
/// corrected after saving.
class DeliveryLineItemsGrid extends StatefulWidget {
  final List<DeliveryLine> lines;
  final void Function(int index, double newCurrentDelivery) onCurrentDeliveryChanged;

  const DeliveryLineItemsGrid({
    super.key,
    required this.lines,
    required this.onCurrentDeliveryChanged,
  });

  @override
  State<DeliveryLineItemsGrid> createState() => _DeliveryLineItemsGridState();
}

class _DeliveryLineItemsGridState extends State<DeliveryLineItemsGrid> {
  final Map<DeliveryLine, TextEditingController> _controllers = {};

  String _formatQty(double qty) => qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();

  TextEditingController _controllerFor(DeliveryLine line) {
    final existing = _controllers[line];
    if (existing != null) return existing;
    final controller = TextEditingController(text: line.currentDelivery == 0 ? '' : _formatQty(line.currentDelivery));
    _controllers[line] = controller;
    return controller;
  }

  void _disposeControllersFor(Iterable<DeliveryLine> removed) {
    for (final line in removed) {
      _controllers.remove(line)?.dispose();
    }
  }

  @override
  void didUpdateWidget(covariant DeliveryLineItemsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.lines.toSet();
    _disposeControllersFor(_controllers.keys.where((l) => !current.contains(l)).toList());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, DeliveryLine line, TextEditingController controller, String value) {
    final parsed = double.tryParse(value) ?? 0;
    final clamped = parsed < 0 ? 0.0 : (parsed > line.balanceQty ? line.balanceQty : parsed);
    widget.onCurrentDeliveryChanged(index, clamped);

    if (clamped != parsed) {
      final formatted = clamped == 0 ? '' : _formatQty(clamped);
      controller.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
      if (parsed > line.balanceQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot exceed balance quantity of ${_formatQty(line.balanceQty)}.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No pending deliveries for this customer.')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.lines.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final line = widget.lines[index];
        final controller = _controllerFor(line);
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
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(isDense: true, labelText: 'Current Delivery', border: OutlineInputBorder()),
                  onChanged: (value) => _onChanged(index, line, controller, value),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
