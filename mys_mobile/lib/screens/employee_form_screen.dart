import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/city.dart';
import '../models/employee.dart';
import '../models/employee_detail.dart';
import '../services/city_service.dart';
import '../services/employee_service.dart';
import 'widgets/search_picker_sheet.dart';

/// Add-or-edit form for an employee, mirroring CustomerFormScreen. In edit
/// mode it also offers Delete. Pops with the saved Employee on save, or
/// `true` on delete — the manage-employees list treats either as "refresh".
class EmployeeFormScreen extends StatefulWidget {
  final EmployeeDetail? editing;
  const EmployeeFormScreen({super.key, this.editing});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.editing?.employeeName);
  late final _printNameController = TextEditingController(text: widget.editing?.printName);
  late final _codeController = TextEditingController(text: widget.editing?.employeeCode);
  late final _addressController = TextEditingController(text: widget.editing?.address);
  late final _pinCodeController = TextEditingController(text: widget.editing?.pinCode);
  late final _phoneController = TextEditingController(text: widget.editing?.phoneNo);
  late final _mobileController = TextEditingController(text: widget.editing?.mobileNo);
  late final _emailController = TextEditingController(text: widget.editing?.emailId);
  final _employeeService = EmployeeService();
  final _cityService = CityService();

  City? _selectedCity;
  bool _isDriver = false;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedCity = City(cityId: editing.cityId, cityName: editing.cityName);
      _isDriver = editing.isDriver;
    }
  }

  Future<void> _pickCity() async {
    final city = await showSearchPicker<City>(
      context: context,
      title: 'Search city',
      search: _cityService.search,
      itemLabel: (c) => c.cityName,
    );
    if (city != null) setState(() => _selectedCity = city);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a city.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final employeeName = _nameController.text.trim();
      final printName = _printNameController.text.trim();
      final employeeCode = _codeController.text.trim();
      final address = _addressController.text.trim();
      final pinCode = _pinCodeController.text.trim();
      final phoneNo = _phoneController.text.trim();
      final mobileNo = _mobileController.text.trim();
      final emailId = _emailController.text.trim();

      final employee = _isEditing
          ? await _employeeService.update(
              employeeId: widget.editing!.employeeId,
              employeeName: employeeName,
              printName: printName.isEmpty ? null : printName,
              employeeCode: employeeCode.isEmpty ? null : employeeCode,
              address: address.isEmpty ? null : address,
              cityId: _selectedCity!.cityId,
              pinCode: pinCode.isEmpty ? null : pinCode,
              phoneNo: phoneNo.isEmpty ? null : phoneNo,
              mobileNo: mobileNo,
              emailId: emailId.isEmpty ? null : emailId,
              isDriver: _isDriver,
            )
          : await _employeeService.create(
              employeeName: employeeName,
              printName: printName.isEmpty ? null : printName,
              employeeCode: employeeCode.isEmpty ? null : employeeCode,
              address: address.isEmpty ? null : address,
              cityId: _selectedCity!.cityId,
              pinCode: pinCode.isEmpty ? null : pinCode,
              phoneNo: phoneNo.isEmpty ? null : phoneNo,
              mobileNo: mobileNo,
              emailId: emailId.isEmpty ? null : emailId,
              isDriver: _isDriver,
            );
      if (!mounted) return;
      Navigator.of(context).pop<Employee>(employee);
    } on EmployeeServiceException catch (e) {
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
        title: const Text('Delete employee?'),
        content: Text('Delete "${widget.editing!.employeeName}"? This cannot be undone from the app.'),
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
      await _employeeService.delete(widget.editing!.employeeId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on EmployeeServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _printNameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _pinCodeController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Employee' : 'Add New Employee'),
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _printNameController,
                decoration: const InputDecoration(labelText: 'Print Name (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Code (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickCity,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'City'),
                  child: Text(_selectedCity?.cityName ?? 'Tap to select a city'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pinCodeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Pin Code (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: const InputDecoration(labelText: 'Phone No (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: const InputDecoration(labelText: 'Mobile No', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email ID (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Is Driver'),
                subtitle: const Text('Enable if this employee can be assigned as a driver'),
                value: _isDriver,
                onChanged: (value) => setState(() => _isDriver = value),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : _save,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _saving ? const CircularProgressIndicator() : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
