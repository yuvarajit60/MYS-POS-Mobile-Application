import 'dart:async';
import 'package:flutter/material.dart';
import '../models/site.dart';
import '../services/site_service.dart';
import 'customer_site_mapping_form_screen.dart';

/// Lists sites with their current customer mapping (or "Not mapped") and
/// lets the user add/change a mapping, or unmap a site back to no customer.
/// Sites themselves are created/edited/deleted from the separate "Site"
/// master (manage_sites_screen.dart) — this screen only edits SITE.CUSTOMERID.
class ManageCustomerSiteMappingsScreen extends StatefulWidget {
  const ManageCustomerSiteMappingsScreen({super.key});

  @override
  State<ManageCustomerSiteMappingsScreen> createState() => _ManageCustomerSiteMappingsScreenState();
}

class _ManageCustomerSiteMappingsScreenState extends State<ManageCustomerSiteMappingsScreen> {
  final _siteService = SiteService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Site> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    try {
      final results = await _siteService.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addNew() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomerSiteMappingFormScreen()),
    );
    if (result != null) _runSearch(_searchController.text);
  }

  Future<void> _edit(Site site) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CustomerSiteMappingFormScreen(editing: site)),
    );
    if (result != null) _runSearch(_searchController.text);
  }

  Future<void> _unmap(Site site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unmap site?'),
        content: Text('Remove the mapping between "${site.siteName}" and "${site.customerName}"? The site itself is not deleted.'),
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

    try {
      await _siteService.assignCustomer(siteId: site.siteId, customerId: null);
      _runSearch(_searchController.text);
    } on SiteServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Site Mapping')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNew,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search site name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(child: Text('No sites found.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final site = _results[index];
                      final mapped = site.customerId != null;
                      return ListTile(
                        title: Text(site.siteName),
                        subtitle: Text(mapped ? site.customerName! : 'Not mapped'),
                        onTap: () => _edit(site),
                        trailing: mapped
                            ? IconButton(
                                icon: const Icon(Icons.link_off, color: Colors.red),
                                tooltip: 'Unmap',
                                onPressed: () => _unmap(site),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
