import 'package:flutter/material.dart';
import '../models/head.dart';
import '../models/head_detail.dart';
import '../services/head_service.dart';

const List<String> _incomeExpenseTypes = ['Expenses', 'Income'];

/// Mapped master choices a Head can offer in Income or Expenses Entry — see
/// 033_head_mapped_master.sql. Kept as a short fixed list (not a generic
/// master picker) since only Employee/Vehicle have dedicated columns on
/// INCOMEOREXPENSES today.
const List<String?> _mappedMasterOptions = [null, 'Employee', 'Vehicle'];

/// Add-or-edit form for a Head Master record, mirroring EmployeeFormScreen.
/// In edit mode it also offers Delete and a Status toggle. Pops with the
/// saved Head on save, or `true` on delete.
class HeadFormScreen extends StatefulWidget {
  final HeadDetail? editing;
  const HeadFormScreen({super.key, this.editing});

  @override
  State<HeadFormScreen> createState() => _HeadFormScreenState();
}

class _HeadFormScreenState extends State<HeadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.editing?.headName);
  late final _printNameController = TextEditingController(text: widget.editing?.printName);
  final _headService = HeadService();

  late String _selectedType = widget.editing?.incomeOrExpenses ?? 'Expenses';
  String? _mappedMaster;
  bool _status = true;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _mappedMaster = editing.mappedMaster;
      _status = editing.status;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final headName = _nameController.text.trim();
      final printName = _printNameController.text.trim();

      final head = _isEditing
          ? await _headService.update(
              headId: widget.editing!.headId,
              headName: headName,
              printName: printName.isEmpty ? null : printName,
              incomeOrExpenses: _selectedType,
              mappedMaster: _mappedMaster,
              status: _status,
            )
          : await _headService.create(
              headName: headName,
              printName: printName.isEmpty ? null : printName,
              incomeOrExpenses: _selectedType,
              mappedMaster: _mappedMaster,
            );
      if (!mounted) return;
      Navigator.of(context).pop<Head>(head);
    } on HeadServiceException catch (e) {
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
        title: const Text('Delete head?'),
        content: Text('Delete "${widget.editing!.headName}"? This cannot be undone from the app.'),
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
      await _headService.delete(widget.editing!.headId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on HeadServiceException catch (e) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Head' : 'Add New Head'),
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
                decoration: const InputDecoration(labelText: 'Head Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _printNameController,
                decoration: const InputDecoration(labelText: 'Print Name (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Text('Type', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [for (final type in _incomeExpenseTypes) ButtonSegment(value: type, label: Text(type))],
                selected: {_selectedType},
                onSelectionChanged: (selection) => setState(() => _selectedType = selection.first),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _mappedMaster,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Mapped Master',
                  helperText: 'Pulls a picker from this master in Income or Expenses Entry',
                ),
                items: [
                  for (final option in _mappedMasterOptions)
                    DropdownMenuItem(value: option, child: Text(option ?? 'None')),
                ],
                onChanged: (value) => setState(() => _mappedMaster = value),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _status,
                  onChanged: (value) => setState(() => _status = value),
                ),
              ],
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
