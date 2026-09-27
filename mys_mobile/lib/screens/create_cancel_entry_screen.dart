import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cancel_entry_option.dart';
import '../models/customer.dart';
import '../services/cancel_entry_service.dart';
import '../services/customer_service.dart';
import 'widgets/search_picker_sheet.dart';

const List<String> cancelEntryTransactionTypes = ['Sales Order', 'Trip Entry', 'Delivery', 'Payment'];

/// Cancels an existing Sales Order/Trip Entry/Delivery/Payment entry.
/// Transaction Type + From/To Date (and an optional Customer) filter a grid
/// of matching entries (Customer/Entry No/Entry Date/Total Amount); tapping
/// a row asks for a Cancel Date + Remarks, then cancels it. Cancelling a
/// Delivery is the special case — the backend also reverses that
/// delivery's lines back out of SALESORDER_DETAILS.DELIVERYQTY (see
/// CancelEntryService on the API side), making that product pending again
/// for a future delivery.
class CreateCancelEntryScreen extends StatefulWidget {
  const CreateCancelEntryScreen({super.key});

  @override
  State<CreateCancelEntryScreen> createState() => _CreateCancelEntryScreenState();
}

class _CreateCancelEntryScreenState extends State<CreateCancelEntryScreen> {
  final _cancelEntryService = CancelEntryService();
  final _customerService = CustomerService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');
  static final _amountFormat = NumberFormat('#,##0.00');

  String? _transactionType;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  Customer? _selectedCustomer;

  bool _loading = false;
  String? _error;
  List<CancelEntryOption>? _results;

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => isFrom ? _fromDate = picked : _toDate = picked);
  }

  Future<void> _pickCustomer() async {
    final customer = await showSearchPicker<Customer>(
      context: context,
      title: 'Search customer (leave blank for all)',
      search: _customerService.search,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
    );
    if (customer != null) setState(() => _selectedCustomer = customer);
  }

  Future<void> _search() async {
    final type = _transactionType;
    if (type == null) {
      _showMessage('Select a transaction type.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _cancelEntryService.searchEntries(
        transactionType: type,
        fromDate: _fromDate,
        toDate: _toDate,
        customerId: _selectedCustomer?.customerId,
      );
      if (!mounted) return;
      setState(() => _results = results);
    } on CancelEntryServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmCancel(CancelEntryOption entry) async {
    final type = _transactionType!;
    final result = await showDialog<_CancelConfirmResult>(
      context: context,
      builder: (context) => _CancelConfirmDialog(transactionType: type, entry: entry),
    );
    if (result == null) return;

    setState(() => _loading = true);
    try {
      await _cancelEntryService.cancel(
        transactionType: type,
        entryNo: entry.entryNo,
        cancelDate: result.cancelDate,
        remarks: result.remarks,
      );
      if (!mounted) return;
      _showMessage('${entry.entryNo} cancelled.');
      _search();
    } on CancelEntryServiceException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cancel Entry')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _transactionType,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Transaction Type'),
                    items: [for (final type in cancelEntryTransactionTypes) DropdownMenuItem(value: type, child: Text(type))],
                    onChanged: (value) => setState(() {
                      _transactionType = value;
                      _results = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickCustomer,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Customer',
                        suffixIcon: _selectedCustomer == null
                            ? null
                            : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _selectedCustomer = null)),
                      ),
                      child: Text(_selectedCustomer?.customerName ?? 'All Customers'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isFrom: true),
                          child: InputDecorator(
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'From Date'),
                            child: Text(_dateFormat.format(_fromDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isFrom: false),
                          child: InputDecorator(
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'To Date'),
                            child: Text(_dateFormat.format(_toDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _search,
                    child: _loading ? const CircularProgressIndicator() : const Text('Search'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  if (_results != null) _buildResults(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final results = _results!;
    if (results.isEmpty) return const Center(child: Text('No entries found for this filter.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in results)
          Card(
            child: ListTile(
              onTap: _loading ? null : () => _confirmCancel(entry),
              title: Text('${entry.customerName}  •  ${entry.entryNo}'),
              subtitle: Text(_dateFormat.format(entry.entryDate)),
              trailing: Text(_amountFormat.format(entry.totalAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

class _CancelConfirmResult {
  final DateTime cancelDate;
  final String? remarks;
  _CancelConfirmResult(this.cancelDate, this.remarks);
}

class _CancelConfirmDialog extends StatefulWidget {
  final String transactionType;
  final CancelEntryOption entry;
  const _CancelConfirmDialog({required this.transactionType, required this.entry});

  @override
  State<_CancelConfirmDialog> createState() => _CancelConfirmDialogState();
}

class _CancelConfirmDialogState extends State<_CancelConfirmDialog> {
  static final _dateFormat = DateFormat('dd-MMM-yyyy');
  final _remarksController = TextEditingController();
  DateTime _cancelDate = DateTime.now();

  Future<void> _pickCancelDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _cancelDate,
      firstDate: DateTime(_cancelDate.year - 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _cancelDate = picked);
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel entry?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cancel ${widget.transactionType} entry "${widget.entry.entryNo}"? This cannot be undone from the app.'),
          if (widget.transactionType == 'Delivery') ...[
            const SizedBox(height: 8),
            const Text(
              'This will also reverse the delivered quantity back to pending for its products.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickCancelDate,
            child: InputDecorator(
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Cancel Date'),
              child: Text(_dateFormat.format(_cancelDate)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _remarksController,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Remarks'),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('No')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            _CancelConfirmResult(_cancelDate, _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim()),
          ),
          child: const Text('Yes, Cancel It', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
