import 'dart:async';
import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';
import 'customer_form_screen.dart';

class ManageCustomersScreen extends StatefulWidget {
  const ManageCustomersScreen({super.key});

  @override
  State<ManageCustomersScreen> createState() => _ManageCustomersScreenState();
}

class _ManageCustomersScreenState extends State<ManageCustomersScreen> {
  final _customerService = CustomerService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Customer> _results = [];
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
      final results = await _customerService.search(query);
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
      MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
    );
    if (result != null) _runSearch(_searchController.text);
  }

  Future<void> _edit(Customer customer) async {
    try {
      final detail = await _customerService.getById(customer.customerId);
      if (!mounted) return;
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CustomerFormScreen(editing: detail)),
      );
      if (result != null) _runSearch(_searchController.text);
    } on CustomerServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text('Delete "${customer.customerName}"? This cannot be undone from the app.'),
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
      await _customerService.delete(customer.customerId);
      _runSearch(_searchController.text);
    } on CustomerServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
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
                labelText: 'Search customer name or mobile number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(child: Text('No customers found.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final customer = _results[index];
                      return ListTile(
                        title: Text(customer.customerName),
                        subtitle: Text(customer.mobileNo),
                        onTap: () => _edit(customer),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _delete(customer),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
