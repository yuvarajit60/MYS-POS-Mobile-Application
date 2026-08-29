import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/driver.dart';
import '../models/employee_vehicle_mapping.dart';
import '../models/vehicle.dart';
import '../services/employee_service.dart';
import '../services/employee_vehicle_mapping_service.dart';
import '../services/vehicle_service.dart';
import 'widgets/search_picker_sheet.dart';

/// Add-or-edit form for a driver↔vehicle mapping. Delete is a genuine hard
/// delete here (see EmployeeVehicleMappingService's backend note — the
/// table has no soft-delete column, and removing a mapping never affects
/// historical trip records since those store their own vehicle snapshot).
class VehicleMappingFormScreen extends StatefulWidget {
  final EmployeeVehicleMapping? editing;
  const VehicleMappingFormScreen({super.key, this.editing});

  @override
  State<VehicleMappingFormScreen> createState() => _VehicleMappingFormScreenState();
}

class _VehicleMappingFormScreenState extends State<VehicleMappingFormScreen> {
  final _mappingService = EmployeeVehicleMappingService();
  final _employeeService = EmployeeService();
  final _vehicleService = VehicleService();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

  Driver? _selectedDriver;
  Vehicle? _selectedVehicle;
  DateTime _validStartDate = DateTime.now();
  DateTime? _validEndDate;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedDriver = Driver(employeeId: editing.employeeId, employeeName: editing.employeeName, mobileNo: '');
      _selectedVehicle = Vehicle(vehicleId: editing.vehicleId, vehicleName: editing.vehicleName);
      _validStartDate = editing.validStartDate;
      _validEndDate = editing.validEndDate;
    }
  }

  Future<void> _pickDriver() async {
    final driver = await showSearchPicker<Driver>(
      context: context,
      title: 'Search driver name',
      search: _employeeService.searchDrivers,
      itemLabel: (d) => d.employeeName,
      itemSubtitle: (d) => d.mobileNo,
    );
    if (driver != null) setState(() => _selectedDriver = driver);
  }

  Future<void> _pickVehicle() async {
    final vehicle = await showSearchPicker<Vehicle>(
      context: context,
      title: 'Search vehicle',
      search: _vehicleService.search,
      itemLabel: (v) => v.vehicleName,
    );
    if (vehicle != null) setState(() => _selectedVehicle = vehicle);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validStartDate,
      firstDate: DateTime(_validStartDate.year - 5),
      lastDate: DateTime(_validStartDate.year + 5),
    );
    if (picked != null) setState(() => _validStartDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validEndDate ?? _validStartDate,
      firstDate: DateTime(_validStartDate.year - 5),
      lastDate: DateTime(_validStartDate.year + 5),
    );
    if (picked != null) setState(() => _validEndDate = picked);
  }

  Future<void> _save() async {
    if (_selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a driver.')));
      return;
    }
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a vehicle.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final mapping = _isEditing
          ? await _mappingService.update(
              mappingId: widget.editing!.mappingId,
              driver: _selectedDriver!,
              vehicle: _selectedVehicle!,
              validStartDate: _validStartDate,
              validEndDate: _validEndDate,
            )
          : await _mappingService.create(
              driver: _selectedDriver!,
              vehicle: _selectedVehicle!,
              validStartDate: _validStartDate,
              validEndDate: _validEndDate,
            );
      if (!mounted) return;
      Navigator.of(context).pop<EmployeeVehicleMapping>(mapping);
    } on EmployeeVehicleMappingServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
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

    setState(() => _deleting = true);
    try {
      await _mappingService.delete(widget.editing!.mappingId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on EmployeeVehicleMappingServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Vehicle Mapping' : 'Add Vehicle Mapping'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete',
              onPressed: busy ? null : _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _pickDriver,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Driver'),
                child: Text(_selectedDriver?.employeeName ?? 'Tap to select a driver'),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickVehicle,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Vehicle'),
                child: Text(_selectedVehicle?.vehicleName ?? 'Tap to select a vehicle'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickStartDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Valid Start Date'),
                      child: Text(_dateFormat.format(_validStartDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickEndDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Valid End Date',
                        suffixIcon: _validEndDate == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() => _validEndDate = null),
                              ),
                      ),
                      child: Text(_validEndDate == null ? 'Ongoing' : _dateFormat.format(_validEndDate!)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : _save,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving ? const CircularProgressIndicator() : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
