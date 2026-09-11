import 'dart:async';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/employee_service.dart';
import 'employee_form_screen.dart';

class ManageEmployeesScreen extends StatefulWidget {
  const ManageEmployeesScreen({super.key});

  @override
  State<ManageEmployeesScreen> createState() => _ManageEmployeesScreenState();
}

class _ManageEmployeesScreenState extends State<ManageEmployeesScreen> {
  final _employeeService = EmployeeService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Employee> _results = [];
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
      final results = await _employeeService.search(query);
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
      MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
    );
    if (result != null) _runSearch(_searchController.text);
  }

  Future<void> _edit(Employee employee) async {
    try {
      final detail = await _employeeService.getById(employee.employeeId);
      if (!mounted) return;
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EmployeeFormScreen(editing: detail)),
      );
      if (result != null) _runSearch(_searchController.text);
    } on EmployeeServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete employee?'),
        content: Text('Delete "${employee.employeeName}"? This cannot be undone from the app.'),
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
      await _employeeService.delete(employee.employeeId);
      _runSearch(_searchController.text);
    } on EmployeeServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
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
                labelText: 'Search employee name or mobile number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(child: Text('No employees found.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final employee = _results[index];
                      return ListTile(
                        title: Text(employee.employeeName),
                        subtitle: Text(employee.mobileNo),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (employee.isDriver)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Chip(
                                  label: const Text('Driver', style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _delete(employee),
                            ),
                          ],
                        ),
                        onTap: () => _edit(employee),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
