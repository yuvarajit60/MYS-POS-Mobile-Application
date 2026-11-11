import 'package:flutter/material.dart';
import '../../models/head_detail.dart';
import '../../services/head_service.dart';

const List<String> _incomeExpenseTypes = ['Expenses', 'Income'];

/// See head_form_screen.dart (mobile) for the same fields/logic as a
/// field-by-field push screen; this is the web equivalent as a modal
/// dialog, the idiomatic web pattern for a small add/edit form.
const List<String?> _mappedMasterOptions = [null, 'Employee', 'Vehicle'];

class HeadFormDialog extends StatefulWidget {
  final HeadDetail? editing;
  const HeadFormDialog({super.key, this.editing});

  @override
  State<HeadFormDialog> createState() => _HeadFormDialogState();
}

class _HeadFormDialogState extends State<HeadFormDialog> {
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

      if (_isEditing) {
        await _headService.update(
          headId: widget.editing!.headId,
          headName: headName,
          printName: printName.isEmpty ? null : printName,
          incomeOrExpenses: _selectedType,
          mappedMaster: _mappedMaster,
          status: _status,
        );
      } else {
        await _headService.create(
          headName: headName,
          printName: printName.isEmpty ? null : printName,
          incomeOrExpenses: _selectedType,
          mappedMaster: _mappedMaster,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
        content: Text('Delete "${widget.editing!.headName}"? This cannot be undone.'),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Head' : 'Add New Head',
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
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Head Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _printNameController,
                  decoration: const InputDecoration(labelText: 'Print Name (optional)'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [for (final type in _incomeExpenseTypes) DropdownMenuItem(value: type, child: Text(type))],
                  onChanged: (value) => setState(() => _selectedType = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _mappedMaster,
                  decoration: const InputDecoration(
                    labelText: 'Mapped Master',
                    helperText: 'Pulls a picker from this master in Income/Expense Entry',
                  ),
                  items: [
                    for (final option in _mappedMasterOptions)
                      DropdownMenuItem(value: option, child: Text(option ?? 'None')),
                  ],
                  onChanged: (value) => setState(() => _mappedMaster = value),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 4),
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
      ),
    );
  }
}
