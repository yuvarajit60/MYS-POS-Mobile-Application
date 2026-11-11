import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/head.dart';
import '../../services/head_service.dart';
import '../widgets/head_form_dialog.dart';

/// Web-only Head Master screen — a data table with inline row actions and
/// an Add button opening a modal form, instead of the mobile app's
/// search-then-push-a-new-screen pattern (see manage_heads_screen.dart).
/// Same HeadService/Head model as mobile; only the presentation differs.
class HeadMasterWebScreen extends StatefulWidget {
  const HeadMasterWebScreen({super.key});

  @override
  State<HeadMasterWebScreen> createState() => _HeadMasterWebScreenState();
}

class _HeadMasterWebScreenState extends State<HeadMasterWebScreen> {
  final _headService = HeadService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Head> _results = [];
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
      final results = await _headService.search(query);
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
    final saved = await showDialog<bool>(context: context, builder: (_) => const HeadFormDialog());
    if (saved == true) _runSearch(_searchController.text);
  }

  Future<void> _edit(Head head) async {
    try {
      final detail = await _headService.getById(head.headId);
      if (!mounted) return;
      final saved = await showDialog<bool>(context: context, builder: (_) => HeadFormDialog(editing: detail));
      if (saved == true) _runSearch(_searchController.text);
    } on HeadServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Head head) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete head?'),
        content: Text('Delete "${head.headName}"? This cannot be undone.'),
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
      await _headService.delete(head.headId);
      _runSearch(_searchController.text);
    } on HeadServiceException catch (e) {
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
                    hintText: 'Search head name',
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
                label: const Text('Add Head'),
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
                  ? const Center(child: Text('No heads found.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(MysColors.bgLight),
                        columns: const [
                          DataColumn(label: Text('Head Name')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Mapped Master')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          for (final head in _results)
                            DataRow(
                              cells: [
                                DataCell(Text(head.headName)),
                                DataCell(_TypeBadge(incomeOrExpenses: head.incomeOrExpenses)),
                                DataCell(Text(head.mappedMaster ?? '—')),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Edit',
                                      onPressed: () => _edit(head),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Delete',
                                      onPressed: () => _delete(head),
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

class _TypeBadge extends StatelessWidget {
  final String incomeOrExpenses;
  const _TypeBadge({required this.incomeOrExpenses});

  @override
  Widget build(BuildContext context) {
    final isIncome = incomeOrExpenses == 'Income';
    final color = isIncome ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(20)),
      child: Text(incomeOrExpenses, style: TextStyle(color: color.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
