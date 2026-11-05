import 'dart:async';
import 'package:flutter/material.dart';
import '../models/head.dart';
import '../services/head_service.dart';
import 'head_form_screen.dart';

class ManageHeadsScreen extends StatefulWidget {
  const ManageHeadsScreen({super.key});

  @override
  State<ManageHeadsScreen> createState() => _ManageHeadsScreenState();
}

class _ManageHeadsScreenState extends State<ManageHeadsScreen> {
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
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HeadFormScreen()),
    );
    if (result != null) _runSearch(_searchController.text);
  }

  Future<void> _edit(Head head) async {
    try {
      final detail = await _headService.getById(head.headId);
      if (!mounted) return;
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HeadFormScreen(editing: detail)),
      );
      if (result != null) _runSearch(_searchController.text);
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
        content: Text('Delete "${head.headName}"? This cannot be undone from the app.'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Head Master')),
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
                labelText: 'Search head name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(child: Text('No heads found.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final head = _results[index];
                      return ListTile(
                        title: Text(head.headName),
                        subtitle: Text(
                          head.mappedMaster == null || head.mappedMaster!.isEmpty
                              ? head.incomeOrExpenses
                              : '${head.incomeOrExpenses} • ${head.mappedMaster}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _delete(head),
                        ),
                        onTap: () => _edit(head),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
