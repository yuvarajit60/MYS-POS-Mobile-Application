import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/area.dart';
import '../../services/area_service.dart';
import '../widgets/area_form_dialog.dart';

/// Web-only Area master screen — same search/table/dialog pattern as the
/// other web masters. No getById needed (Area already carries its City).
class AreaMasterWebScreen extends StatefulWidget {
  const AreaMasterWebScreen({super.key});

  @override
  State<AreaMasterWebScreen> createState() => _AreaMasterWebScreenState();
}

class _AreaMasterWebScreenState extends State<AreaMasterWebScreen> {
  final _areaService = AreaService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Area> _results = [];
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
      final results = await _areaService.search(query);
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
    final saved = await showDialog<bool>(context: context, builder: (_) => const AreaFormDialog());
    if (saved == true) _runSearch(_searchController.text);
  }

  Future<void> _edit(Area area) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => AreaFormDialog(editing: area));
    if (saved == true) _runSearch(_searchController.text);
  }

  Future<void> _delete(Area area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete area?'),
        content: Text('Delete "${area.areaName}"? This cannot be undone.'),
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
      await _areaService.delete(area.areaId);
      _runSearch(_searchController.text);
    } on AreaServiceException catch (e) {
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
                    hintText: 'Search area name',
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
                label: const Text('Add Area'),
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
                  ? const Center(child: Text('No areas found.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(MysColors.bgLight),
                        columns: const [
                          DataColumn(label: Text('Area Name')),
                          DataColumn(label: Text('City')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          for (final area in _results)
                            DataRow(
                              cells: [
                                DataCell(Text(area.areaName)),
                                DataCell(Text(area.cityName)),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Edit',
                                      onPressed: () => _edit(area),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Delete',
                                      onPressed: () => _delete(area),
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
