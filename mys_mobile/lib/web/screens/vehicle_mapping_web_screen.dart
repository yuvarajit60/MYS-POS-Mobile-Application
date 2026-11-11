import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../models/employee_vehicle_mapping.dart';
import '../../services/employee_vehicle_mapping_service.dart';
import '../widgets/vehicle_mapping_form_dialog.dart';

/// Web-only Employee Vehicle Mapping screen — same search/table/dialog
/// pattern as the other web masters. Same EmployeeVehicleMappingService/
/// model as mobile.
class VehicleMappingWebScreen extends StatefulWidget {
  const VehicleMappingWebScreen({super.key});

  @override
  State<VehicleMappingWebScreen> createState() => _VehicleMappingWebScreenState();
}

class _VehicleMappingWebScreenState extends State<VehicleMappingWebScreen> {
  final _mappingService = EmployeeVehicleMappingService();
  final _searchController = TextEditingController();
  Timer? _debounce;
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

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
    final saved = await showDialog<bool>(context: context, builder: (_) => const VehicleMappingFormDialog());
    if (saved == true) _runSearch(_searchController.text);
  }

  Future<void> _edit(EmployeeVehicleMapping mapping) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => VehicleMappingFormDialog(editing: mapping));
    if (saved == true) _runSearch(_searchController.text);
  }

  Future<void> _delete(EmployeeVehicleMapping mapping) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete mapping?'),
        content: const Text('Delete this vehicle mapping? This cannot be undone.'),
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
                    hintText: 'Search driver or vehicle name',
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
                  ? const Center(child: Text('No mappings found.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(MysColors.bgLight),
                        columns: const [
                          DataColumn(label: Text('Driver')),
                          DataColumn(label: Text('Vehicle')),
                          DataColumn(label: Text('Valid From')),
                          DataColumn(label: Text('Valid To')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          for (final mapping in _results)
                            DataRow(
                              cells: [
                                DataCell(Text(mapping.employeeName)),
                                DataCell(Text(mapping.vehicleName)),
                                DataCell(Text(_dateFormat.format(mapping.validStartDate))),
                                DataCell(Text(mapping.validEndDate == null ? 'Ongoing' : _dateFormat.format(mapping.validEndDate!))),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Edit',
                                      onPressed: () => _edit(mapping),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Delete',
                                      onPressed: () => _delete(mapping),
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
