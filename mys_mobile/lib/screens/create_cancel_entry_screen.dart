import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cancel_entry_option.dart';
import '../services/cancel_entry_service.dart';
import 'widgets/search_picker_sheet.dart';

const List<String> cancelEntryTransactionTypes = ['Sales Order', 'Trip Entry', 'Delivery', 'Payment'];

/// Cancels an existing Sales Order/Trip Entry/Delivery/Payment entry. Entry
/// No is scoped to the chosen Transaction Type + Cancel Date, so picking
/// either resets the selected entry. Cancelling a Delivery is the special
/// case — the backend also reverses that delivery's lines back out of
/// SALESORDER_DETAILS.DELIVERYQTY (see CancelEntryService on the API side),
/// making that product pending again for a future delivery.
class CreateCancelEntryScreen extends StatefulWidget {
  const CreateCancelEntryScreen({super.key});

  @override
  State<CreateCancelEntryScreen> createState() => _CreateCancelEntryScreenState();
}

class _CreateCancelEntryScreenState extends State<CreateCancelEntryScreen> {
  final _cancelEntryService = CancelEntryService();
  final _remarksController = TextEditingController();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

  String? _transactionType;
  DateTime _cancelDate = DateTime.now();
  CancelEntryOption? _selectedEntry;
  bool _saving = false;

  Future<void> _pickCancelDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _cancelDate,
      firstDate: DateTime(_cancelDate.year - 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _cancelDate = picked;
      _selectedEntry = null;
    });
  }

  Future<void> _pickEntry() async {
    final type = _transactionType;
    if (type == null) {
      _showMessage('Select a transaction type first.');
      return;
    }

    final entry = await showSearchPicker<CancelEntryOption>(
      context: context,
      title: 'Search entry no',
      search: (query) async {
        final all = await _cancelEntryService.searchEntries(transactionType: type, date: _cancelDate);
        if (query.trim().isEmpty) return all;
        final q = query.toLowerCase();
        return all.where((o) => o.entryNo.toLowerCase().contains(q)).toList();
      },
      itemLabel: (o) => o.entryNo,
      itemSubtitle: (o) => o.description,
    );
    if (entry != null) setState(() => _selectedEntry = entry);
  }

  Future<void> _confirmAndCancel() async {
    final type = _transactionType;
    final entry = _selectedEntry;
    if (type == null) {
      _showMessage('Select a transaction type.');
      return;
    }
    if (entry == null) {
      _showMessage('Select an entry to cancel.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel entry?'),
        content: Text(
          'Cancel $type entry "${entry.entryNo}"? This cannot be undone from the app.'
          '${type == 'Delivery' ? '\n\nThis will also reverse the delivered quantity back to pending for its products.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel It', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await _cancelEntryService.cancel(
        transactionType: type,
        entryNo: entry.entryNo,
        cancelDate: _cancelDate,
        remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      );
      if (!mounted) return;
      _showMessage('${entry.entryNo} cancelled.');
      Navigator.of(context).pop();
    } on CancelEntryServiceException catch (e) {
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
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cancel Entry')),
      body: SingleChildScrollView(
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
                _selectedEntry = null;
              }),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickCancelDate,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Cancel Date'),
                child: Text(_dateFormat.format(_cancelDate)),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickEntry,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Entry No'),
                child: Text(
                  _selectedEntry == null
                      ? (_transactionType == null ? 'Select a transaction type first' : 'Tap to select an entry')
                      : '${_selectedEntry!.entryNo}  (${_selectedEntry!.description})',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _remarksController,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Remarks'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _confirmAndCancel,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red,
              ),
              child: _saving ? const CircularProgressIndicator() : const Text('Cancel Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
