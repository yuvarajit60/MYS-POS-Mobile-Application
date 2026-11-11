import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/site.dart';
import '../../services/site_service.dart';
import '../widgets/site_form_dialog.dart';

/// Web-only Site master screen — same search/table/dialog pattern as the
/// other web masters. Customer mapping is deliberately not editable here,
/// same as mobile — see Customer Site Mapping.
class SiteMasterWebScreen extends StatefulWidget {
  const SiteMasterWebScreen({super.key});

  @override
  State<SiteMasterWebScreen> createState() => _SiteMasterWebScreenState();
}

class _SiteMasterWebScreenState extends State<SiteMasterWebScreen> {
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
    final saved = await showDialog<Object>(context: context, builder: (_) => const SiteFormDialog());
    if (saved != null) _runSearch(_searchController.text);
  }

  Future<void> _edit(Site site) async {
    try {
      final detail = await _siteService.getById(site.siteId);
      if (!mounted) return;
      final saved = await showDialog<Object>(context: context, builder: (_) => SiteFormDialog(editing: detail));
      if (saved != null) _runSearch(_searchController.text);
    } on SiteServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Site site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete site?'),
        content: Text('Delete "${site.siteName}"? This cannot be undone.'),
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

    try {
      await _siteService.delete(site.siteId);
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
                label: const Text('Add Site'),
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
                          DataColumn(label: Text('Area')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          for (final site in _results)
                            DataRow(
                              cells: [
                                DataCell(Text(site.siteName)),
                                DataCell(Text(site.areaName)),
                                DataCell(Text(site.customerName ?? '—')),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Edit',
                                      onPressed: () => _edit(site),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Delete',
                                      onPressed: () => _delete(site),
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
