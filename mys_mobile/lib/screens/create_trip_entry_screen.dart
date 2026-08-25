import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/driver.dart';
import '../models/driver_vehicle.dart';
import '../models/product.dart';
import '../models/site.dart';
import '../models/trip_entry_line.dart';
import '../services/employee_service.dart';
import '../services/product_service.dart';
import '../services/site_service.dart';
import '../services/trip_entry_service.dart';
import 'widgets/search_picker_sheet.dart';
import 'widgets/trip_entry_line_items_grid.dart';

/// Mobile version of the desktop app's Trip Entry screen — logs equipment
/// usage (e.g. excavator hours/meter) billed to a customer's site, driven
/// by a driver. No Location picker here: like every other mobile screen,
/// it's implicit from the logged-in user's own LOCATIONID, not a free
/// cross-location dropdown as on the desktop screen this mirrors.
///
/// Customer is picked indirectly: the rep searches Sites (not customers)
/// and the customer is derived from SITE.CUSTOMERID — there's no separate
/// "pick a customer" step, per how the desktop screen's data model works.
class CreateTripEntryScreen extends StatefulWidget {
  const CreateTripEntryScreen({super.key});

  @override
  State<CreateTripEntryScreen> createState() => _CreateTripEntryScreenState();
}

class _CreateTripEntryScreenState extends State<CreateTripEntryScreen> {
  final _employeeService = EmployeeService();
  final _siteService = SiteService();
  final _productService = ProductService();
  final _tripEntryService = TripEntryService();

  final _tripNoController = TextEditingController();

  Customer? _selectedCustomer;
  Driver? _selectedDriver;
  Site? _selectedSite;
  DriverVehicle? _driverVehicle;
  DateTime _tripDate = DateTime.now();
  final List<TripEntryLine> _lines = [];
  bool _saving = false;

  double get _grandTotal => _lines.fold(0, (sum, line) => sum + line.totalAmount);

  // Matches the backend's rounding: NETAMOUNT is rounded to the nearest
  // whole rupee, with the difference stored as ROUNDOFF.
  double get _roundedGrandTotal => _grandTotal.roundToDouble();

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
      _driverVehicle = vehicle;
      for (final line in _lines) {
        line.vehicleId = vehicle.vehicleId;
        line.vehicleName = vehicle.vehicleName;
      }
    });
  }

  Future<void> _pickSite() async {
    final site = await showSearchPicker<Site>(
      context: context,
      title: 'Search site',
      search: _siteService.search,
      itemLabel: (s) => s.siteName,
      itemSubtitle: (s) => '${s.customerName} • ${s.areaName}',
    );
    if (site == null) return;

    setState(() {
      _selectedSite = site;
      _selectedCustomer = Customer(
        customerId: site.customerId,
        customerName: site.customerName,
        mobileNo: site.mobileNo,
      );
    });
  }

  Future<void> _pickTripDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tripDate,
      firstDate: DateTime(_tripDate.year - 1),
      lastDate: DateTime(_tripDate.year + 1),
    );
    if (picked != null) setState(() => _tripDate = picked);
  }

  Future<void> _addProduct() async {
    final product = await showSearchPicker<Product>(
      context: context,
      title: 'Search product',
      search: _productService.search,
      itemLabel: (p) => p.productName,
      itemSubtitle: (p) => 'MRP: ${p.rate.toStringAsFixed(2)}',
    );
    if (product == null) return;

    setState(() {
      _lines.add(TripEntryLine(
        product: product,
        vehicleId: _driverVehicle?.vehicleId,
        vehicleName: _driverVehicle?.vehicleName,
      ));
    });
  }

  void _onMeterOrHoursChanged(int index, MeterOrHours value) => setState(() => _lines[index].meterOrHours = value);

  void _onTimeStartChanged(int index, DateTime value) => setState(() {
        _lines[index].timeStart = value;
        _recomputeQty(index);
      });

  void _onTimeCloseChanged(int index, DateTime value) => setState(() {
        _lines[index].timeClose = value;
        _recomputeQty(index);
      });

  void _onMeterStartChanged(int index, double value) => setState(() {
        _lines[index].meterStart = value;
        _recomputeQty(index);
      });

  void _onMeterCloseChanged(int index, double value) => setState(() {
        _lines[index].meterClose = value;
        _recomputeQty(index);
      });

  /// Auto-fills Qty from the Hours (TimeClose - TimeStart, in hours) or
  /// Meter ((MeterClose - MeterStart) / 10, since meter readings are in
  /// tenths) pair once both sides are set — Qty stays directly editable
  /// afterward, same as Rate, in case the rep needs to override it.
  void _recomputeQty(int index) {
    final line = _lines[index];
    if (line.meterOrHours == MeterOrHours.hours) {
      final start = line.timeStart;
      final close = line.timeClose;
      if (start != null && close != null) {
        final hours = close.difference(start).inMinutes / 60.0;
        if (hours > 0) line.qty = hours;
      }
    } else {
      final start = line.meterStart;
      final close = line.meterClose;
      if (start != null && close != null && close > start) {
        // Meter readings are in tenths (e.g. 320 means 32.0), so the raw
        // difference is divided by 10 to get the billable quantity.
        line.qty = (close - start) / 10;
      }
    }
  }

  void _onQtyChanged(int index, double newQty) => setState(() => _lines[index].qty = newQty);

  void _onRateChanged(int index, double newRate) => setState(() => _lines[index].rate = newRate);

  void _onDeleteLine(int index) => setState(() => _lines.removeAt(index));

  Future<void> _saveAndClose() async {
    if (_selectedSite == null || _selectedCustomer == null) {
      _showMessage('Select a site.');
      return;
    }
    if (_selectedDriver == null) {
      _showMessage('Select a driver.');
      return;
    }
    if (_tripNoController.text.trim().isEmpty) {
      _showMessage('Enter a trip number.');
      return;
    }
    if (_lines.isEmpty) {
      _showMessage('Add at least one product.');
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await _tripEntryService.create(
        customer: _selectedCustomer!,
        site: _selectedSite!,
        driver: _selectedDriver!,
        tripNo: _tripNoController.text.trim(),
        tripDate: _tripDate,
        lines: _lines,
      );
      if (!mounted) return;
      _showMessage('Trip entry ${result.entryNo} saved.');
      Navigator.of(context).pop();
    } on TripEntryException catch (e) {
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
    _tripNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Driver', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDriver,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Driver'),
                child: Text(_selectedDriver == null ? 'Tap to select a driver' : _selectedDriver!.employeeName),
              ),
            ),
            if (_driverVehicle?.vehicleName != null) ...[
              const SizedBox(height: 4),
              Text('Vehicle: ${_driverVehicle!.vehicleName}', style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            Text('Site', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickSite,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Site Name'),
                child: Text(_selectedSite == null ? 'Tap to select a site' : _selectedSite!.siteName),
              ),
            ),
            const SizedBox(height: 16),
            // Read-only — derived from the selected site's CUSTOMERID, not
            // independently pickable.
            InputDecorator(
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Customer'),
              child: Text(
                _selectedCustomer == null
                    ? 'Select a site to fill this in'
                    : '${_selectedCustomer!.customerName}  (${_selectedCustomer!.mobileNo})',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tripNoController,
                    decoration: const InputDecoration(labelText: 'Trip No', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickTripDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Trip Date'),
                      child: Text('${_tripDate.day.toString().padLeft(2, '0')}-${_tripDate.month.toString().padLeft(2, '0')}-${_tripDate.year}'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Products', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
              ],
            ),
            TripEntryLineItemsGrid(
              lines: _lines,
              onMeterOrHoursChanged: _onMeterOrHoursChanged,
              onTimeStartChanged: _onTimeStartChanged,
              onTimeCloseChanged: _onTimeCloseChanged,
              onMeterStartChanged: _onMeterStartChanged,
              onMeterCloseChanged: _onMeterCloseChanged,
              onQtyChanged: _onQtyChanged,
              onRateChanged: _onRateChanged,
              onDelete: _onDeleteLine,
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(_roundedGrandTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _saveAndClose,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving ? const CircularProgressIndicator() : const Text('Save and Close'),
            ),
          ],
        ),
      ),
    );
  }
}
