import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/customer.dart';
import '../models/delivery_line.dart';
import '../models/driver.dart';
import '../models/vehicle.dart';
import '../services/delivery_service.dart';
import '../services/employee_service.dart';
import '../services/vehicle_service.dart';
import 'widgets/delivery_line_items_grid.dart';
import 'widgets/search_picker_sheet.dart';

/// Vehicle numbers (e.g. "TN33BL8268") are always uppercase letters/digits,
/// max 10 characters — enforced as the rep types, not just on save.
class _VehicleNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final upper = newValue.text.toUpperCase();
    final filtered = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final truncated = filtered.length > 10 ? filtered.substring(0, 10) : filtered;
    return TextEditingValue(text: truncated, selection: TextSelection.collapsed(offset: truncated.length));
  }
}

/// Records delivery of already-created Sales Order lines. Deliberately
/// create-only, with no edit path at all — once saved, SALESORDER_DETAILS.
/// DELIVERYQTY has already been updated server-side, so an "edit" would
/// need its own reversal logic that doesn't exist. The confirmation
/// dialog before saving exists specifically because of this.
class CreateDeliveryScreen extends StatefulWidget {
  const CreateDeliveryScreen({super.key});

  @override
  State<CreateDeliveryScreen> createState() => _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends State<CreateDeliveryScreen> {
  final _deliveryService = DeliveryService();
  final _employeeService = EmployeeService();
  final _vehicleService = VehicleService();
  final _vehicleNumberController = TextEditingController();

  Customer? _selectedCustomer;
  Driver? _selectedDriver;
  List<DeliveryLine> _lines = [];
  bool _loadingLines = false;
  bool _saving = false;

  Future<void> _pickCustomer() async {
    final customer = await showSearchPicker<Customer>(
      context: context,
      title: 'Search customer with pending deliveries',
      search: _deliveryService.searchPendingCustomers,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
    );
    if (customer == null) return;

    setState(() {
      _selectedCustomer = customer;
      _loadingLines = true;
      _lines = [];
    });
    try {
      final lines = await _deliveryService.getPendingLines(customer.customerId);
      if (!mounted) return;
      setState(() => _lines = lines);
    } on DeliveryServiceException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loadingLines = false);
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
    if (driver == null) return;

    final vehicle = await _employeeService.getVehicle(driver.employeeId);
    if (!mounted) return;
    setState(() {
      _selectedDriver = driver;
      _vehicleNumberController.text = _normalizeVehicleNo(vehicle.vehicleName ?? '');
    });
  }

  Future<void> _pickVehicle() async {
    final vehicle = await showSearchPicker<Vehicle>(
      context: context,
      title: 'Search vehicle number',
      search: _vehicleService.search,
      itemLabel: (v) => v.vehicleName,
    );
    if (vehicle != null) setState(() => _vehicleNumberController.text = _normalizeVehicleNo(vehicle.vehicleName));
  }

  String _normalizeVehicleNo(String value) {
    final upper = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return upper.length > 10 ? upper.substring(0, 10) : upper;
  }

  void _onCurrentDeliveryChanged(int index, double value) {
    setState(() => _lines[index].currentDelivery = value);
  }

  Future<void> _save() async {
    if (_selectedDriver == null) {
      _showMessage('Select a driver.');
      return;
    }
    final linesToSave = _lines.where((l) => l.currentDelivery > 0).toList();
    if (linesToSave.isEmpty) {
      _showMessage('Enter a delivery quantity for at least one line.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save delivery?'),
        content: const Text(
          'Once saved, this delivery entry cannot be edited or undone from the app. '
          'Double-check the quantities before continuing.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final result = await _deliveryService.create(
        driver: _selectedDriver!,
        vehicleNumber: _vehicleNumberController.text.trim(),
        lines: linesToSave,
      );
      if (!mounted) return;
      _showMessage('Delivery saved: ${result.deliveryNo}');
      Navigator.of(context).pop();
    } on DeliveryServiceException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Customer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickCustomer,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Customer'),
                child: Text(
                  _selectedCustomer == null
                      ? 'Tap to select a customer'
                      : '${_selectedCustomer!.customerName}  (${_selectedCustomer!.mobileNo})',
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_loadingLines) const Center(child: CircularProgressIndicator()),
            if (!_loadingLines && _selectedCustomer != null) ...[
              Text('Pending Deliveries', style: Theme.of(context).textTheme.titleMedium),
              DeliveryLineItemsGrid(
                lines: _lines,
                onCurrentDeliveryChanged: _onCurrentDeliveryChanged,
              ),
              const SizedBox(height: 24),
              Text('Delivery Group', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDriver,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Driver'),
                  child: Text(_selectedDriver?.employeeName ?? 'Tap to select a driver'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vehicleNumberController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [_VehicleNumberFormatter()],
                decoration: InputDecoration(
                  labelText: 'Vehicle No',
                  border: const OutlineInputBorder(),
                  helperText: 'Auto-filled from the driver\'s mapped vehicle — edit or pick another if needed.',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.list_alt),
                    tooltip: 'Pick from all vehicles',
                    onPressed: _pickVehicle,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _saving ? const CircularProgressIndicator() : const Text('Save'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
