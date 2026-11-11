import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/city.dart';
import '../../models/customer.dart';
import '../../models/customer_detail.dart';
import '../../services/city_service.dart';
import '../../services/customer_service.dart';
import 'web_search_picker.dart';

/// See customer_form_screen.dart (mobile) for the same fields/logic as a
/// field-by-field push screen; this is the web equivalent as a modal
/// dialog (see HeadFormDialog).
class CustomerFormDialog extends StatefulWidget {
  final CustomerDetail? editing;
  const CustomerFormDialog({super.key, this.editing});

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.editing?.customerName);
  late final _mobileController = TextEditingController(text: widget.editing?.mobileNo);
  late final _addressController = TextEditingController(text: widget.editing?.address);
  final _customerService = CustomerService();
  final _cityService = CityService();

  City? _selectedCity;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedCity = City(cityId: editing.cityId, cityName: editing.cityName);
    }
  }

  Future<void> _pickCity() async {
    final city = await showWebSearchPicker<City>(
      context: context,
      title: 'Search city',
      search: _cityService.search,
      itemLabel: (c) => c.cityName,
    );
    if (city != null) setState(() => _selectedCity = city);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a city.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final customerName = _nameController.text.trim();
      final mobileNo = _mobileController.text.trim();
      final address = _addressController.text.trim();

      final customer = _isEditing
          ? await _customerService.update(
              customerId: widget.editing!.customerId,
              customerName: customerName,
              mobileNo: mobileNo,
              city: _selectedCity!,
              address: address.isEmpty ? null : address,
            )
          : await _customerService.create(
              customerName: customerName,
              mobileNo: mobileNo,
              city: _selectedCity!,
              address: address.isEmpty ? null : address,
            );
      if (!mounted) return;
      Navigator.of(context).pop<Customer>(customer);
    } on CustomerServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text('Delete "${widget.editing!.customerName}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await _customerService.delete(widget.editing!.customerId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CustomerServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Customer' : 'Add New Customer',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_isEditing)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: busy ? null : _confirmDelete,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: busy ? null : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Customer Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  decoration: const InputDecoration(labelText: 'Mobile No'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickCity,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'City'),
                    child: Text(_selectedCity?.cityName ?? 'Click to select a city'),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address (optional)'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : _save,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
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
    );
  }
}
