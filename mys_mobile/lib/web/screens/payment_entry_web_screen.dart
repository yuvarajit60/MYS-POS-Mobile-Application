import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../models/customer.dart';
import '../../models/payment_type.dart';
import '../../services/payment_service.dart';
import '../widgets/web_search_picker.dart';

/// Web equivalent of create_payment_screen.dart (mobile) — records a
/// payment against a customer's delivered goods. Create-only, same as
/// mobile: no edit/reversal path once saved.
class PaymentEntryWebScreen extends StatefulWidget {
  const PaymentEntryWebScreen({super.key});

  @override
  State<PaymentEntryWebScreen> createState() => _PaymentEntryWebScreenState();
}

class _PaymentEntryWebScreenState extends State<PaymentEntryWebScreen> {
  final _paymentService = PaymentService();
  final _amountController = TextEditingController();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

  Customer? _selectedCustomer;
  String _selectedPaymentType = paymentTypes.first;
  DateTime _paymentDate = DateTime.now();
  bool _saving = false;

  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(_paymentDate.year - 1),
      lastDate: DateTime(_paymentDate.year + 1),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _pickCustomer() async {
    final customer = await showWebSearchPicker<Customer>(
      context: context,
      title: 'Search customer with delivered goods',
      search: _paymentService.searchDeliveredCustomers,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
    );
    if (customer != null) setState(() => _selectedCustomer = customer);
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      _showMessage('Select a customer.');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid payment amount.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save payment?'),
        content: const Text('Once saved, this payment entry cannot be edited or undone from the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final result = await _paymentService.create(
        customerId: _selectedCustomer!.customerId,
        amount: amount,
        paymentType: _selectedPaymentType,
        paymentDate: _paymentDate,
      );
      if (!mounted) return;
      _showMessage('Payment saved: ${result.paymentNo}');
      setState(() {
        _selectedCustomer = null;
        _amountController.clear();
      });
    } on PaymentServiceException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MysColors.bgLight,
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: _pickCustomer,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Customer'),
                      child: Text(
                        _selectedCustomer == null
                            ? 'Click to select a customer'
                            : '${_selectedCustomer!.customerName}  (${_selectedCustomer!.mobileNo})',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount Received', prefixText: '₹ '),
                  ),
                  const SizedBox(height: 16),
                  Text('Payment Type', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [for (final type in paymentTypes) ButtonSegment(value: type, label: Text(type))],
                    selected: {_selectedPaymentType},
                    onSelectionChanged: (selection) => setState(() => _selectedPaymentType = selection.first),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickPaymentDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Payment Date'),
                      child: Text(_dateFormat.format(_paymentDate)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
