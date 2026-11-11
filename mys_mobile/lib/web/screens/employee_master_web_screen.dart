import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/employee.dart';
import '../../services/employee_service.dart';
import '../widgets/employee_form_dialog.dart';

/// Web-only Employee master screen — same search/table/dialog pattern as
/// the other web masters. Same EmployeeService/Employee model as mobile.
class EmployeeMasterWebScreen extends StatefulWidget {
  const EmployeeMasterWebScreen({super.key});

  @override
  State<EmployeeMasterWebScreen> createState() => _EmployeeMasterWebScreenState();
}

class _EmployeeMasterWebScreenState extends State<EmployeeMasterWebScreen> {
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
    final saved = await showDialog<Object>(context: context, builder: (_) => const EmployeeFormDialog());
    if (saved != null) _runSearch(_searchController.text);
  }

  Future<void> _edit(Employee employee) async {
    try {
      final detail = await _employeeService.getById(employee.employeeId);
      if (!mounted) return;
      final saved = await showDialog<Object>(context: context, builder: (_) => EmployeeFormDialog(editing: detail));
      if (saved != null) _runSearch(_searchController.text);
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
        content: Text('Delete "${employee.employeeName}"? This cannot be undone.'),
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
                    hintText: 'Search employee name or mobile number',
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
                label: const Text('Add Employee'),
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
                  ? const Center(child: Text('No employees found.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(MysColors.bgLight),
                        columns: const [
                          DataColumn(label: Text('Employee Name')),
                          DataColumn(label: Text('Mobile No')),
                          DataColumn(label: Text('Driver')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          for (final employee in _results)
                            DataRow(
                              cells: [
                                DataCell(Text(employee.employeeName)),
                                DataCell(Text(employee.mobileNo)),
                                DataCell(employee.isDriver
                                    ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                                    : const Text('—')),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Edit',
                                      onPressed: () => _edit(employee),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Delete',
                                      onPressed: () => _delete(employee),
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
