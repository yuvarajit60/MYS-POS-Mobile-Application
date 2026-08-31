import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/city.dart';
import '../models/customer.dart';
import '../models/customer_detail.dart';
import '../services/city_service.dart';
import '../services/customer_service.dart';
import 'widgets/search_picker_sheet.dart';

/// Add-or-edit form for a customer. In create mode (no [editing] passed) this
/// is the quick "add a customer on the spot" flow used by field reps mid-order
/// and from the landing page. In edit mode (an existing [CustomerDetail]
/// passed in) it also offers Delete. Pops with the saved Customer on
/// save, or `true` on delete — callers that only care "did something change"
/// (the manage-customers list) can treat either as "refresh".
class CustomerFormScreen extends StatefulWidget {
  final CustomerDetail? editing;
  const CustomerFormScreen({super.key, this.editing});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
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
    final city = await showSearchPicker<City>(
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
      final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();

      final customer = _isEditing
          ? await _customerService.update(
              customerId: widget.editing!.customerId,
              customerName: customerName,
              mobileNo: mobileNo,
              city: _selectedCity!,
              address: address,
            )
          : await _customerService.create(
              customerName: customerName,
              mobileNo: mobileNo,
              city: _selectedCity!,
              address: address,
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
        content: Text('Delete "${widget.editing!.customerName}"? This cannot be undone from the app.'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Customer' : 'Add New Customer'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete',
              onPressed: busy ? null : _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickCity,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'City'),
                  child: Text(_selectedCity?.cityName ?? 'Tap to select a city'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : _save,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _saving ? const CircularProgressIndicator() : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
