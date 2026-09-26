import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/driver.dart';
import '../models/driver_vehicle.dart';
import '../models/product.dart';
import '../models/site.dart';
import '../models/site_detail.dart';
import '../models/trip_entry_line.dart';
import '../services/customer_service.dart';
import '../services/employee_service.dart';
import '../services/product_service.dart';
import '../services/site_service.dart';
import '../services/trip_entry_service.dart';
import 'customer_form_screen.dart';
import 'site_form_screen.dart';
import 'widgets/search_picker_sheet.dart';
import 'widgets/trip_entry_line_items_grid.dart';

/// Mobile version of the desktop app's Trip Entry screen — logs equipment
/// usage (e.g. excavator hours/meter) billed to a customer's site, driven
/// by a driver. No Location picker here: like every other mobile screen,
/// it's implicit from the logged-in user's own LOCATIONID, not a free
/// cross-location dropdown as on the desktop screen this mirrors.
///
/// Selection order is Driver -> Customer -> Site, matching Sales Order/
/// Delivery Entry. Site search prefers sites already mapped to the
/// selected customer, but also allows any other existing site (a site can
/// be reused across different customers over time, unlike Sales Order/
/// Delivery which only ever search this customer's own sites). Picking a
/// site that isn't already mapped to the selected customer is a new
/// Customer + Site combination, so it's recorded into SITE_MAPPING via
/// SiteService.assignCustomer before use — same as "Add New Site"/
/// "Add New Customer" already do for brand-new records.
class CreateTripEntryScreen extends StatefulWidget {
  const CreateTripEntryScreen({super.key});

  @override
  State<CreateTripEntryScreen> createState() => _CreateTripEntryScreenState();
}

class _CreateTripEntryScreenState extends State<CreateTripEntryScreen> {
  final _employeeService = EmployeeService();
  final _siteService = SiteService();
  final _customerService = CustomerService();
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

  Future<void> _pickCustomer() async {
    final customer = await showSearchPicker<Customer>(
      context: context,
      title: 'Search customer name or mobile number',
      search: _customerService.search,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
      addNewLabel: 'Add New Customer',
      onAddNew: (context) => Navigator.of(context).push<Customer>(
        MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
      ),
    );
    if (customer == null) return;
    setState(() {
      _selectedCustomer = customer;
      _selectedSite = null;
    });
  }

  /// Sites already mapped to the selected customer come first, followed by
  /// every other existing site (deduplicated) — a site not yet linked to
  /// this customer is still pickable, since sites get reused across jobs
  /// for different customers rather than belonging to one forever.
  Future<List<Site>> _searchSitesForCustomer(String query) async {
    final results = await Future.wait([
      _siteService.search(query, customerId: _selectedCustomer!.customerId),
      _siteService.search(query),
    ]);
    final mapped = results[0];
    final all = results[1];
    final mappedIds = mapped.map((s) => s.siteId).toSet();
    return [...mapped, ...all.where((s) => !mappedIds.contains(s.siteId))];
  }

  Future<void> _pickSite() async {
    if (_selectedCustomer == null) {
      _showMessage('Select a customer first.');
      return;
    }

    final site = await showSearchPicker<Site>(
      context: context,
      title: 'Search site',
      search: _searchSitesForCustomer,
      itemLabel: (s) => s.siteName,
      itemSubtitle: (s) =>
          s.customerId == _selectedCustomer!.customerId ? s.areaName : '${s.customerName ?? 'Not mapped'} • ${s.areaName}',
      addNewLabel: 'Add New Site',
      onAddNew: (context) async {
        final detail = await Navigator.of(context).push<SiteDetail>(
          MaterialPageRoute(builder: (_) => const SiteFormScreen()),
        );
        if (detail == null) return null;
        // Site master creates bare (unmapped) sites; map it to the
        // customer already selected here so it's immediately usable.
        final mapped = await _siteService.assignCustomer(
          siteId: detail.siteId,
          customerId: _selectedCustomer!.customerId,
        );
        return _siteFromDetail(mapped);
      },
    );
    if (site == null) return;

    if (site.customerId == _selectedCustomer!.customerId) {
      setState(() => _selectedSite = site);
      return;
    }

    // New Customer + Site combination (the site was unmapped, or mapped to
    // a different customer) — record it in SITE_MAPPING before using it.
    try {
      final mapped = await _siteService.assignCustomer(
        siteId: site.siteId,
        customerId: _selectedCustomer!.customerId,
      );
      setState(() => _selectedSite = _siteFromDetail(mapped));
    } on SiteServiceException catch (e) {
      _showMessage(e.message);
    }
  }

  Site _siteFromDetail(SiteDetail detail) => Site(
        siteId: detail.siteId,
        siteName: detail.siteName,
        areaName: detail.areaName,
        customerId: detail.customerId,
        customerName: detail.customerName,
        mobileNo: _selectedCustomer?.mobileNo ?? '',
      );

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

  // A line can only bill by Hours or by Meter, never both — switching modes
  // clears the other mode's fields so stale readings never get saved
  // alongside the new ones, and Qty resets until the rep fills in the
  // newly-active pair.
  void _onMeterOrHoursChanged(int index, MeterOrHours value) => setState(() {
        final line = _lines[index];
        line.meterOrHours = value;
        if (value == MeterOrHours.hours) {
          line.meterStart = null;
          line.meterClose = null;
        } else {
          line.timeStart = null;
          line.timeClose = null;
        }
        line.qty = 1;
      });

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

  /// Auto-fills Qty from the Hours (TimeClose - TimeStart) or Meter
  /// (MeterClose - MeterStart, entered directly as decimal hours — e.g.
  /// 120.4 to 122.6 is a 2.2 hour / 2h12m difference) pair once both
  /// sides are set — Qty stays directly editable afterward, same as Rate,
  /// in case the rep needs to override it.
  ///
  /// Hours mode bills the exact elapsed time (e.g. 2h15m = 2.25, billed as
  /// 2400 for the 2 hours plus 300 for the 15 minutes at a 1200/hr rate) —
  /// rounded only to the nearest hundredth to absorb the repeating decimals
  /// dividing minutes by 60 produces (e.g. 2.3666666666666667), not to
  /// the nearest tenth: that previously overbilled ties like 2.25 by
  /// rounding up to 2.3 (18 min instead of 15).
  ///
  /// Meter mode keeps rounding to the nearest tenth of an hour (0.1 = 6
  /// minutes) — a mechanical hour-meter reads in tenths, so e.g. 2h08m
  /// (2.1333... true hours) bills as 2.1, not 2.13.
  void _recomputeQty(int index) {
    final line = _lines[index];
    if (line.meterOrHours == MeterOrHours.hours) {
      final start = line.timeStart;
      final close = line.timeClose;
      if (start != null && close != null) {
        final hours = close.difference(start).inMinutes / 60.0;
        if (hours > 0) line.qty = _roundToHundredth(hours);
      }
    } else {
      final start = line.meterStart;
      final close = line.meterClose;
      if (start != null && close != null && close > start) {
        // Meter readings are decimal hours (0.1 = 6 minutes), so the raw
        // difference is already the billable quantity.
        line.qty = _roundToTenth(close - start);
      }
    }
  }

  double _roundToTenth(double value) => (value * 10).round() / 10;

  double _roundToHundredth(double value) => (value * 100).round() / 100;

  void _onQtyChanged(int index, double newQty) => setState(() => _lines[index].qty = newQty);

  void _onRateChanged(int index, double newRate) => setState(() => _lines[index].rate = newRate);

  void _onDeleteLine(int index) => setState(() => _lines.removeAt(index));

  Future<void> _saveAndClose() async {
    if (_selectedDriver == null) {
      _showMessage('Select a driver.');
      return;
    }
    if (_selectedCustomer == null) {
      _showMessage('Select a customer.');
      return;
    }
    if (_selectedSite == null) {
      _showMessage('Select a site.');
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
            Text('Customer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickCustomer,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Customer'),
                child: Text(
                  _selectedCustomer == null ? 'Tap to select a customer' : '${_selectedCustomer!.customerName}  (${_selectedCustomer!.mobileNo})',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Site', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickSite,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Site Name'),
                child: Text(
                  _selectedSite == null ? (_selectedCustomer == null ? 'Select a customer first' : 'Tap to select a site') : _selectedSite!.siteName,
                ),
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
