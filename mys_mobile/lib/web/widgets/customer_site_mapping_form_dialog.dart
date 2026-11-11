import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/site.dart';
import '../../services/customer_service.dart';
import '../../services/site_service.dart';
import 'web_search_picker.dart';

/// Web equivalent of customer_site_mapping_form_screen.dart (mobile) — see
/// that file's header for why this has no mapping ID of its own: a site
/// maps to at most one customer, so "editing" just changes which customer
/// a site points to, and "unmap" clears it back to unmapped.
class CustomerSiteMappingFormDialog extends StatefulWidget {
  final Site? editing;
  const CustomerSiteMappingFormDialog({super.key, this.editing});

  @override
  State<CustomerSiteMappingFormDialog> createState() => _CustomerSiteMappingFormDialogState();
}

class _CustomerSiteMappingFormDialogState extends State<CustomerSiteMappingFormDialog> {
  final _siteService = SiteService();
  final _customerService = CustomerService();

  Site? _selectedSite;
  Customer? _selectedCustomer;
  bool _saving = false;
  bool _unmapping = false;

  bool get _isEditing => widget.editing != null;
  bool get _wasMapped => widget.editing?.customerId != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedSite = editing;
      if (editing.customerId != null) {
        _selectedCustomer = Customer(
          customerId: editing.customerId!,
          customerName: editing.customerName ?? '',
          mobileNo: editing.mobileNo,
        );
      }
    }
  }

  Future<void> _pickSite() async {
    final site = await showWebSearchPicker<Site>(
      context: context,
      title: 'Search site',
      search: _siteService.search,
      itemLabel: (s) => s.siteName,
      itemSubtitle: (s) => s.customerName ?? 'Not mapped',
    );
    if (site != null) setState(() => _selectedSite = site);
  }

  Future<void> _pickCustomer() async {
    final customer = await showWebSearchPicker<Customer>(
      context: context,
      title: 'Search customer name or mobile number',
      search: _customerService.search,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
    );
    if (customer != null) setState(() => _selectedCustomer = customer);
  }

  Future<void> _save() async {
    if (_selectedSite == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a site.')));
      return;
    }
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a customer.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await _siteService.assignCustomer(siteId: _selectedSite!.siteId, customerId: _selectedCustomer!.customerId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on SiteServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmUnmap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unmap site?'),
        content: Text('Remove the customer mapping for "${_selectedSite!.siteName}"? The site itself is not deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unmap', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _unmapping = true);
    try {
      await _siteService.assignCustomer(siteId: _selectedSite!.siteId, customerId: null);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on SiteServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _unmapping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _unmapping;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Mapping' : 'Add Mapping',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_isEditing && _wasMapped)
                    IconButton(
                      icon: const Icon(Icons.link_off, color: Colors.red),
                      tooltip: 'Unmap',
                      onPressed: busy ? null : _confirmUnmap,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: busy ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickSite,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Site'),
                  child: Text(_selectedSite?.siteName ?? 'Click to select a site'),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickCustomer,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Customer'),
                  child: Text(_selectedCustomer?.customerName ?? 'Click to select a customer'),
                ),
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
    );
  }
}
