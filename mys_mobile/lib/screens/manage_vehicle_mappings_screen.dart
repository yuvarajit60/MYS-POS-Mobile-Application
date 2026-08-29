import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee_vehicle_mapping.dart';
import '../services/employee_vehicle_mapping_service.dart';
import 'vehicle_mapping_form_screen.dart';

class ManageVehicleMappingsScreen extends StatefulWidget {
  const ManageVehicleMappingsScreen({super.key});

  @override
  State<ManageVehicleMappingsScreen> createState() => _ManageVehicleMappingsScreenState();
}

class _ManageVehicleMappingsScreenState extends State<ManageVehicleMappingsScreen> {
  final _mappingService = EmployeeVehicleMappingService();
  final _searchController = TextEditingController();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');
  Timer? _debounce;

  List<EmployeeVehicleMapping> _results = [];
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
      final results = await _mappingService.search(query);
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
      MaterialPageRoute(builder: (_) => const VehicleMappingFormScreen()),
    );
    if (result != null) _runSearch(_searchController.text);
  }

  Future<void> _edit(EmployeeVehicleMapping mapping) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehicleMappingFormScreen(editing: mapping)),
    );
    if (result != null) _runSearch(_searchController.text);
  }

  Future<void> _delete(EmployeeVehicleMapping mapping) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete mapping?'),
        content: Text('Delete the mapping between "${mapping.employeeName}" and "${mapping.vehicleName}"? This cannot be undone.'),
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
      await _mappingService.delete(mapping.mappingId);
      _runSearch(_searchController.text);
    } on EmployeeVehicleMappingServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _dateRange(EmployeeVehicleMapping m) {
    final end = m.validEndDate == null ? 'ongoing' : _dateFormat.format(m.validEndDate!);
    return '${_dateFormat.format(m.validStartDate)} to $end';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Mappings')),
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
                labelText: 'Search driver or vehicle name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(child: Text('No vehicle mappings found.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final mapping = _results[index];
                      return ListTile(
                        title: Text('${mapping.employeeName} → ${mapping.vehicleName}'),
                        subtitle: Text(_dateRange(mapping)),
                        onTap: () => _edit(mapping),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _delete(mapping),
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
