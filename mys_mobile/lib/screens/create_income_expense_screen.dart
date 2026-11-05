import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/head.dart';
import '../models/vehicle.dart';
import '../services/employee_service.dart';
import '../services/income_expense_service.dart';
import '../services/vehicle_service.dart';
import 'widgets/search_picker_sheet.dart';

const List<String> incomeExpenseTypes = ['Expenses', 'Income'];
const String _employeeMappedMaster = 'Employee';
const String _vehicleMappedMaster = 'Vehicle';

/// Income or Expenses — mirrors the desktop app's existing Income/Expenses
/// entry exactly (same Head master, same shared TRANSACTIONS sequence),
/// with one mobile-specific addition: a Head whose Head Master record maps
/// it to Employee or Vehicle (e.g. "SALARY ADVANCE" -> Employee, "FUEL" ->
/// Vehicle) asks for that master here instead of leaving the rep to type it
/// into Particulars by hand. Unlike other entry screens, Entry Date here
/// defaults to today's actual device date, not the legacy desktop
/// "business date" (dbo.CHANGE_DATE) — entries made after business hours
/// but before a desktop day-close were otherwise getting dated into the
/// past and silently missing the report's default date-range filter.
class CreateIncomeExpenseScreen extends StatefulWidget {
  const CreateIncomeExpenseScreen({super.key});

  @override
  State<CreateIncomeExpenseScreen> createState() => _CreateIncomeExpenseScreenState();
}

class _CreateIncomeExpenseScreenState extends State<CreateIncomeExpenseScreen> {
  final _incomeExpenseService = IncomeExpenseService();
  final _employeeService = EmployeeService();
  final _vehicleService = VehicleService();
  final _particularsController = TextEditingController();
  final _amountController = TextEditingController();
  static final _dateFormat = DateFormat('dd-MMM-yyyy');

  String _selectedType = 'Expenses';
  DateTime? _entryDate;
  List<Head>? _heads;
  Head? _selectedHead;
  Employee? _selectedEmployee;
  Vehicle? _selectedVehicle;
  bool _loadingHeads = false;
  bool _saving = false;

  bool get _isSalaryAdvance => _selectedHead?.mappedMaster == _employeeMappedMaster;
  bool get _isFuel => _selectedHead?.mappedMaster == _vehicleMappedMaster;

  @override
  void initState() {
    super.initState();
    _entryDate = DateTime.now();
    _loadHeads();
  }

  Future<void> _loadHeads() async {
    setState(() {
      _loadingHeads = true;
      _selectedHead = null;
      _selectedEmployee = null;
      _selectedVehicle = null;
    });
    try {
      final heads = await _incomeExpenseService.getHeads(incomeOrExpenses: _selectedType);
      if (!mounted) return;
      setState(() => _heads = heads);
    } finally {
      if (mounted) setState(() => _loadingHeads = false);
    }
  }

  Future<void> _pickEntryDate() async {
    final initial = _entryDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: DateTime(initial.year + 1),
    );
    if (picked != null) setState(() => _entryDate = picked);
  }

  Future<void> _pickEmployee() async {
    final employee = await showSearchPicker<Employee>(
      context: context,
      title: 'Search employee',
      search: _employeeService.search,
      itemLabel: (e) => e.employeeName,
      itemSubtitle: (e) => e.mobileNo,
    );
    if (employee != null) setState(() => _selectedEmployee = employee);
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

  Future<void> _save() async {
    final head = _selectedHead;
    if (head == null) {
      _showMessage('Select a head.');
      return;
    }
    if (_isSalaryAdvance && _selectedEmployee == null) {
      _showMessage('Select an employee for this head.');
      return;
    }
    if (_isFuel && _selectedVehicle == null) {
      _showMessage('Select a vehicle for this head.');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid amount.');
      return;
    }

    setState(() => _saving = true);
    try {
      final entryNo = await _incomeExpenseService.create(
        entryDate: _entryDate ?? DateTime.now(),
        incomeOrExpenses: _selectedType,
        headId: head.headId,
        particulars: _particularsController.text.trim().isEmpty ? null : _particularsController.text.trim(),
        amount: amount,
        employeeId: _isSalaryAdvance ? _selectedEmployee!.employeeId : null,
        vehicleId: _isFuel ? _selectedVehicle!.vehicleId : null,
      );
      if (!mounted) return;
      _showMessage('Entry $entryNo saved.');
      Navigator.of(context).pop();
    } on IncomeExpenseServiceException catch (e) {
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
    _particularsController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Income or Expenses')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Type', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [for (final type in incomeExpenseTypes) ButtonSegment(value: type, label: Text(type))],
              selected: {_selectedType},
              onSelectionChanged: (selection) {
                setState(() => _selectedType = selection.first);
                _loadHeads();
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickEntryDate,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Entry Date'),
                child: Text(_dateFormat.format(_entryDate ?? DateTime.now())),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Head>(
              initialValue: _selectedHead,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Head',
                suffixIcon: _loadingHeads
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
              ),
              items: [for (final head in _heads ?? []) DropdownMenuItem(value: head, child: Text(head.headName))],
              onChanged: (value) => setState(() {
                _selectedHead = value;
                _selectedEmployee = null;
                _selectedVehicle = null;
              }),
            ),
            if (_isSalaryAdvance) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickEmployee,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Employee'),
                  child: Text(_selectedEmployee?.employeeName ?? 'Tap to select an employee'),
                ),
              ),
            ],
            if (_isFuel) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickVehicle,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Vehicle'),
                  child: Text(_selectedVehicle?.vehicleName ?? 'Tap to select a vehicle'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _particularsController,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Particulars'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder(), prefixText: '₹ '),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving ? const CircularProgressIndicator() : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
