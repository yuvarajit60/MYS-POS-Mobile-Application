import 'package:flutter/material.dart';
import '../models/city.dart';
import '../models/customer.dart';
import '../models/site_detail.dart';
import '../services/city_service.dart';
import '../services/customer_service.dart';
import '../services/site_service.dart';
import 'widgets/search_picker_sheet.dart';

/// Add-or-edit form for a Site — maps a site/delivery location to the
/// customer it belongs to. Mirrors CustomerFormScreen's structure.
class SiteFormScreen extends StatefulWidget {
  final SiteDetail? editing;
  const SiteFormScreen({super.key, this.editing});

  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _siteNameController = TextEditingController(text: widget.editing?.siteName);
  late final _areaNameController = TextEditingController(text: widget.editing?.areaName);
  final _siteService = SiteService();
  final _customerService = CustomerService();
  final _cityService = CityService();

  Customer? _selectedCustomer;
  City? _selectedCity;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedCustomer = Customer(customerId: editing.customerId, customerName: editing.customerName, mobileNo: '');
      _selectedCity = City(cityId: editing.cityId, cityName: editing.cityName);
    }
  }

  Future<void> _pickCustomer() async {
    final customer = await showSearchPicker<Customer>(
      context: context,
      title: 'Search customer name or mobile number',
      search: _customerService.search,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
    );
    if (customer != null) setState(() => _selectedCustomer = customer);
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
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a customer.')));
      return;
    }
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a city.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final siteName = _siteNameController.text.trim();
      final areaName = _areaNameController.text.trim();

      final site = _isEditing
          ? await _siteService.update(
              siteId: widget.editing!.siteId,
              siteName: siteName,
              areaName: areaName,
              city: _selectedCity!,
              customer: _selectedCustomer!,
            )
          : await _siteService.create(
              siteName: siteName,
              areaName: areaName,
              city: _selectedCity!,
              customer: _selectedCustomer!,
            );
      if (!mounted) return;
      Navigator.of(context).pop<SiteDetail>(site);
    } on SiteServiceException catch (e) {
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
        title: const Text('Delete site?'),
        content: Text('Delete "${widget.editing!.siteName}"? This cannot be undone from the app.'),
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
      await _siteService.delete(widget.editing!.siteId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on SiteServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _areaNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Site' : 'Add New Site'),
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
              InkWell(
                onTap: _pickCustomer,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Customer Name'),
                  child: Text(_selectedCustomer?.customerName ?? 'Tap to select a customer'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _siteNameController,
                decoration: const InputDecoration(labelText: 'Site Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _areaNameController,
                decoration: const InputDecoration(labelText: 'Area Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickCity,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'City'),
                  child: Text(_selectedCity?.cityName ?? 'Tap to select a city'),
                ),
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
