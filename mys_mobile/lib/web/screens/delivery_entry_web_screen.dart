import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../models/customer.dart';
import '../../models/delivery_line.dart';
import '../../models/driver.dart';
import '../../models/site.dart';
import '../../models/site_detail.dart';
import '../../models/vehicle.dart';
import '../../screens/widgets/delivery_line_items_grid.dart';
import '../../services/delivery_service.dart';
import '../../services/employee_service.dart';
import '../../services/site_service.dart';
import '../../services/vehicle_service.dart';
import '../widgets/site_form_dialog.dart';
import '../widgets/web_search_picker.dart';

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

/// Web equivalent of create_delivery_screen.dart (mobile) — records
/// delivery of already-created Sales Order lines. Create-only, no edit
/// path (see mobile's header comment for why).
class DeliveryEntryWebScreen extends StatefulWidget {
  const DeliveryEntryWebScreen({super.key});

  @override
  State<DeliveryEntryWebScreen> createState() => _DeliveryEntryWebScreenState();
}

class _DeliveryEntryWebScreenState extends State<DeliveryEntryWebScreen> {
  final _deliveryService = DeliveryService();
  final _employeeService = EmployeeService();
  final _vehicleService = VehicleService();
  final _siteService = SiteService();
  final _vehicleNumberController = TextEditingController();

  Customer? _selectedCustomer;
  Site? _selectedSite;
  Driver? _selectedDriver;
  List<DeliveryLine> _lines = [];
  bool _loadingLines = false;
  bool _saving = false;

  Future<void> _pickCustomer() async {
    final customer = await showWebSearchPicker<Customer>(
      context: context,
      title: 'Search customer with pending deliveries',
      search: _deliveryService.searchPendingCustomers,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
    );
    if (customer == null) return;

    setState(() {
      _selectedCustomer = customer;
      _selectedSite = null;
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

  Future<void> _pickSite() async {
    if (_selectedCustomer == null) {
      _showMessage('Select a customer first.');
      return;
    }

    final site = await showWebSearchPicker<Site>(
      context: context,
      title: 'Search site',
      search: (query) => _siteService.search(query, customerId: _selectedCustomer!.customerId),
      itemLabel: (s) => s.siteName,
      itemSubtitle: (s) => s.areaName,
      addNewLabel: 'Add New Site',
      onAddNew: (context) async {
        final detail = await showDialog<SiteDetail>(context: context, builder: (_) => const SiteFormDialog());
        if (detail == null) return null;
        // Site master creates bare (unmapped) sites; map it to the
        // customer already selected here so it's immediately usable.
        final mapped = await _siteService.assignCustomer(
          siteId: detail.siteId,
          customerId: _selectedCustomer!.customerId,
        );
        return Site(
          siteId: mapped.siteId,
          siteName: mapped.siteName,
          areaName: mapped.areaName,
          customerId: mapped.customerId,
          customerName: mapped.customerName,
          mobileNo: _selectedCustomer!.mobileNo,
        );
      },
    );
    if (site != null) setState(() => _selectedSite = site);
  }

  Future<void> _pickDriver() async {
    final driver = await showWebSearchPicker<Driver>(
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
    final vehicle = await showWebSearchPicker<Vehicle>(
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
        siteId: _selectedSite?.siteId,
        lines: linesToSave,
      );
      if (!mounted) return;
      _showMessage('Delivery saved: ${result.deliveryNo}');
      setState(() {
        _selectedCustomer = null;
        _selectedSite = null;
        _selectedDriver = null;
        _vehicleNumberController.clear();
        _lines = [];
      });
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
    return Container(
      color: MysColors.bgLight,
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Customer', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickCustomer,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Customer'),
                        child: Text(
                          _selectedCustomer == null
                              ? 'Click to select a customer'
                              : '${_selectedCustomer!.customerName}  (${_selectedCustomer!.mobileNo})',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickSite,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Site'),
                        child: Text(
                          _selectedSite == null
                              ? 'Click to select a site'
                              : '${_selectedSite!.siteName}  (${_selectedSite!.areaName})',
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
                          decoration: const InputDecoration(labelText: 'Driver'),
                          child: Text(_selectedDriver?.employeeName ?? 'Click to select a driver'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _vehicleNumberController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [_VehicleNumberFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Vehicle No',
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
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
