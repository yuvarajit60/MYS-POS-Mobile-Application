import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/current_date_provider.dart';
import '../models/customer.dart';
import '../models/payment_type.dart';
import '../services/payment_service.dart';
import 'widgets/search_picker_sheet.dart';

/// Records a payment received against a customer's delivered goods.
/// Customer selection is restricted to customers with actual delivery
/// history (see PaymentService.searchDeliveredCustomers). Create-only,
/// same as Delivery Entry — no edit/reversal path exists once saved.
class CreatePaymentScreen extends StatefulWidget {
  const CreatePaymentScreen({super.key});

  @override
  State<CreatePaymentScreen> createState() => _CreatePaymentScreenState();
}

class _CreatePaymentScreenState extends State<CreatePaymentScreen> {
  final _paymentService = PaymentService();
  final _amountController = TextEditingController();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

  Customer? _selectedCustomer;
  String _selectedPaymentType = paymentTypes.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    CurrentDateProvider.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _pickCustomer() async {
    final customer = await showSearchPicker<Customer>(
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
      );
      if (!mounted) return;
      _showMessage('Payment saved: ${result.paymentNo}');
      Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Customer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickCustomer,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Customer'),
                child: Text(
                  _selectedCustomer == null
                      ? 'Tap to select a customer'
                      : '${_selectedCustomer!.customerName}  (${_selectedCustomer!.mobileNo})',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount Received', border: OutlineInputBorder(), prefixText: '₹ '),
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
            InputDecorator(
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Payment Date'),
              child: Text(_dateFormat.format(CurrentDateProvider.instance.currentDate)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving ? const CircularProgressIndicator() : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
