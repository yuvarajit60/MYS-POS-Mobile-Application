import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/site.dart';
import '../../services/site_service.dart';
import '../widgets/customer_site_mapping_form_dialog.dart';

/// Web-only Customer Site Mapping screen — mirrors
/// manage_customer_site_mappings_screen.dart (mobile): lists sites with
/// their current customer, add/change/unmap via a modal. Sites themselves
/// are still only created/edited/deleted from the Site master.
class CustomerSiteMappingWebScreen extends StatefulWidget {
  const CustomerSiteMappingWebScreen({super.key});

  @override
  State<CustomerSiteMappingWebScreen> createState() => _CustomerSiteMappingWebScreenState();
}

class _CustomerSiteMappingWebScreenState extends State<CustomerSiteMappingWebScreen> {
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
    final saved = await showDialog<bool>(context: context, builder: (_) => const CustomerSiteMappingFormDialog());
    if (saved == true) _runSearch(_searchController.text);
  }

  Future<void> _edit(Site site) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => CustomerSiteMappingFormDialog(editing: site));
    if (saved == true) _runSearch(_searchController.text);
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
    return Container(
      color: MysColors.bgLight,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search site name',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: _onChanged,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addNew,
                icon: const Icon(Icons.add),
                label: const Text('Add Mapping'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: _results.isEmpty && !_loading
                  ? const Center(child: Text('No sites found.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(MysColors.bgLight),
                        columns: const [
                          DataColumn(label: Text('Site Name')),
                          DataColumn(label: Text('Mapped Customer')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          for (final site in _results)
                            DataRow(
                              cells: [
                                DataCell(Text(site.siteName)),
                                DataCell(Text(site.customerId != null ? site.customerName! : 'Not mapped')),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Edit',
                                      onPressed: () => _edit(site),
                                    ),
                                    if (site.customerId != null)
                                      IconButton(
                                        icon: const Icon(Icons.link_off, size: 20, color: Colors.red),
                                        tooltip: 'Unmap',
                                        onPressed: () => _unmap(site),
                                      ),
                                  ],
                                )),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
