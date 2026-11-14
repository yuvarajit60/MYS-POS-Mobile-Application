import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../models/customer.dart';
import '../../models/sales_entry_option.dart';
import '../../screens/delivery_detail_screen.dart';
import '../../screens/trip_entry_detail_screen.dart';
import '../../services/customer_service.dart';
import '../../services/sales_entry_service.dart';
import '../widgets/web_search_picker.dart';

/// Web equivalent of create_sales_entry_screen.dart (mobile) — see that
/// file's header for why each selected row becomes its own separate Sales
/// entry. The read-only drill-down detail screens (DeliveryDetailScreen/
/// TripEntryDetailScreen) are reused as-is via a normal page push — purely
/// informational, so a full re-skin isn't needed there yet.
class SalesEntryWebScreen extends StatefulWidget {
  final VoidCallback onClose;
  const SalesEntryWebScreen({super.key, required this.onClose});

  @override
  State<SalesEntryWebScreen> createState() => _SalesEntryWebScreenState();
}

class _SalesEntryWebScreenState extends State<SalesEntryWebScreen> {
  final _salesEntryService = SalesEntryService();
  final _customerService = CustomerService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');
  static final _amountFormat = NumberFormat('#,##0.00');

  Customer? _selectedCustomer;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  bool _loading = false;
  bool _saving = false;
  String? _error;
  List<SalesEntryOption>? _results;
  final Set<String> _selectedKeys = {};

  String _keyOf(SalesEntryOption o) => '${o.sourceType}|${o.entryNo}';

  double get _grandTotal => (_results ?? [])
      .where((o) => _selectedKeys.contains(_keyOf(o)))
      .fold<double>(0, (sum, o) => sum + o.totalAmount);

  Future<void> _pickCustomer() async {
    final customer = await showWebSearchPicker<Customer>(
      context: context,
      title: 'Search customer (leave blank for all)',
      search: _customerService.search,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
    );
    if (customer != null) setState(() => _selectedCustomer = customer);
  }

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

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _salesEntryService.search(
        customerId: _selectedCustomer?.customerId,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _selectedKeys.clear();
      });
    } on SalesEntryServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _viewDetail(SalesEntryOption option) {
    if (option.sourceType == 'Delivery') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeliveryDetailScreen(deliveryNo: option.entryNo)));
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TripEntryDetailScreen(tripEntryId: option.tripEntryId!)));
    }
  }

  void _toggle(SalesEntryOption option, bool? checked) {
    setState(() {
      final key = _keyOf(option);
      if (checked == true) {
        _selectedKeys.add(key);
      } else {
        _selectedKeys.remove(key);
      }
    });
  }

  Future<void> _save() async {
    final selected = (_results ?? []).where((o) => _selectedKeys.contains(_keyOf(o))).toList();
    if (selected.isEmpty) {
      _showMessage('Select at least one entry.');
      return;
    }

    setState(() => _saving = true);
    try {
      final entryNumbers = await _salesEntryService.create(
        selected.map((o) => SalesEntrySource(sourceType: o.sourceType, entryNo: o.entryNo)).toList(),
      );
      if (!mounted) return;
      final message = entryNumbers.length == 1
          ? 'Sales entry ${entryNumbers.first} saved.'
          : '${entryNumbers.length} sales entries saved: ${entryNumbers.join(', ')}';
      _showMessage(message);
      _resetSelection();
    } on SalesEntryServiceException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _close() => widget.onClose();

  void _resetSelection() {
    setState(() {
      _results = null;
      _selectedKeys.clear();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _saving;
    return Container(
      color: MysColors.bgLight,
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: _pickCustomer,
                          child: InputDecorator(
                            decoration: InputDecoration(
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
                                  decoration: const InputDecoration(labelText: 'Entry Date From'),
                                  child: Text(_dateFormat.format(_fromDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDate(isFrom: false),
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Entry Date To'),
                                  child: Text(_dateFormat.format(_toDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: busy ? null : _search,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Search'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_results != null) _buildResults(busy),
                if (_results?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(_amountFormat.format(_grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: busy ? null : _close,
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                                  child: const Text('Close'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FilledButton(
                                  onPressed: busy || _selectedKeys.isEmpty ? null : _save,
                                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Save'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(bool busy) {
    final results = _results!;
    if (results.isEmpty) {
      return const Center(child: Text('No pending Delivery/Trip Entry entries found for this filter.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in results)
          Card(
            color: option.customerHasGst ? Colors.amber.shade50 : null,
            child: CheckboxListTile(
              value: _selectedKeys.contains(_keyOf(option)),
              onChanged: busy ? null : (checked) => _toggle(option, checked),
              title: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: busy ? null : () => _viewDetail(option),
                  child: Text(
                    option.entryNo,
                    style: const TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ),
              subtitle: Text(
                '${option.customerName}${option.customerHasGst ? '  •  GST' : ''}\n'
                '${_dateFormat.format(option.entryDate)}   Qty: ${_amountFormat.format(option.totalQty)}',
              ),
              isThreeLine: true,
              secondary: Text(_amountFormat.format(option.totalAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}
