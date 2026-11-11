import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/driver.dart';
import '../../models/employee_vehicle_mapping.dart';
import '../../models/vehicle.dart';
import '../../services/employee_service.dart';
import '../../services/employee_vehicle_mapping_service.dart';
import '../../services/vehicle_service.dart';
import 'web_search_picker.dart';

/// See vehicle_mapping_form_screen.dart (mobile) for the same fields/logic
/// as a field-by-field push screen; this is the web equivalent as a modal
/// dialog (see HeadFormDialog).
class VehicleMappingFormDialog extends StatefulWidget {
  final EmployeeVehicleMapping? editing;
  const VehicleMappingFormDialog({super.key, this.editing});

  @override
  State<VehicleMappingFormDialog> createState() => _VehicleMappingFormDialogState();
}

class _VehicleMappingFormDialogState extends State<VehicleMappingFormDialog> {
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
    final driver = await showWebSearchPicker<Driver>(
      context: context,
      title: 'Search driver name',
      search: _employeeService.searchDrivers,
      itemLabel: (d) => d.employeeName,
      itemSubtitle: (d) => d.mobileNo,
    );
    if (driver != null) setState(() => _selectedDriver = driver);
  }

  Future<void> _pickVehicle() async {
    final vehicle = await showWebSearchPicker<Vehicle>(
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
      if (_isEditing) {
        await _mappingService.update(
          mappingId: widget.editing!.mappingId,
          driver: _selectedDriver!,
          vehicle: _selectedVehicle!,
          validStartDate: _validStartDate,
          validEndDate: _validEndDate,
        );
      } else {
        await _mappingService.create(
          driver: _selectedDriver!,
          vehicle: _selectedVehicle!,
          validStartDate: _validStartDate,
          validEndDate: _validEndDate,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Vehicle Mapping' : 'Add Vehicle Mapping',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete',
                      onPressed: busy ? null : _confirmDelete,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: busy ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDriver,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Driver'),
                  child: Text(_selectedDriver?.employeeName ?? 'Click to select a driver'),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickVehicle,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                  child: Text(_selectedVehicle?.vehicleName ?? 'Click to select a vehicle'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickStartDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Valid Start Date'),
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
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : _save,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
