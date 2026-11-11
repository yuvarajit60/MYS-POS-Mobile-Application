import 'package:flutter/material.dart';
import '../../models/area.dart';
import '../../models/city.dart';
import '../../services/area_service.dart';
import '../../services/city_service.dart';
import 'web_search_picker.dart';

/// Web equivalent of the mobile Area add/edit form — Area Name + City.
/// No delete confirmation lives inside this dialog (Area has no delete
/// button on mobile's form either; deletion is row-level on the list).
class AreaFormDialog extends StatefulWidget {
  final Area? editing;
  const AreaFormDialog({super.key, this.editing});

  @override
  State<AreaFormDialog> createState() => _AreaFormDialogState();
}

class _AreaFormDialogState extends State<AreaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.editing?.areaName);
  final _areaService = AreaService();
  final _cityService = CityService();

  City? _selectedCity;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedCity = City(cityId: editing.cityId, cityName: editing.cityName);
    }
  }

  Future<void> _pickCity() async {
    final city = await showWebSearchPicker<City>(
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
      final areaName = _nameController.text.trim();

      if (_isEditing) {
        await _areaService.update(areaId: widget.editing!.areaId, areaName: areaName, city: _selectedCity!);
      } else {
        await _areaService.create(areaName: areaName, city: _selectedCity!);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AreaServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
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
                        _isEditing ? 'Edit Area' : 'Add New Area',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Area Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickCity,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'City'),
                    child: Text(_selectedCity?.cityName ?? 'Click to select a city'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
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
