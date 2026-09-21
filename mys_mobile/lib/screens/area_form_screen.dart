import 'package:flutter/material.dart';
import '../models/area.dart';
import '../models/city.dart';
import '../services/area_service.dart';
import '../services/city_service.dart';
import 'widgets/search_picker_sheet.dart';

/// Add-or-edit form for an Area — maps an area to the city it belongs to.
/// Mirrors SiteFormScreen's structure.
class AreaFormScreen extends StatefulWidget {
  final Area? editing;
  final City? initialCity;
  const AreaFormScreen({super.key, this.editing, this.initialCity});

  @override
  State<AreaFormScreen> createState() => _AreaFormScreenState();
}

class _AreaFormScreenState extends State<AreaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _areaNameController = TextEditingController(text: widget.editing?.areaName);
  final _areaService = AreaService();
  final _cityService = CityService();

  City? _selectedCity;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedCity = City(cityId: editing.cityId, cityName: editing.cityName);
    } else if (widget.initialCity != null) {
      _selectedCity = widget.initialCity;
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
      final areaName = _areaNameController.text.trim();

      final area = _isEditing
          ? await _areaService.update(areaId: widget.editing!.areaId, areaName: areaName, city: _selectedCity!)
          : await _areaService.create(areaName: areaName, city: _selectedCity!);
      if (!mounted) return;
      Navigator.of(context).pop<Area>(area);
    } on AreaServiceException catch (e) {
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
        title: const Text('Delete area?'),
        content: Text('Delete "${widget.editing!.areaName}"? This cannot be undone from the app.'),
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
      await _areaService.delete(widget.editing!.areaId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AreaServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _areaNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Area' : 'Add New Area'),
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
              InkWell(
                onTap: _pickCity,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'City'),
                  child: Text(_selectedCity?.cityName ?? 'Tap to select a city'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _areaNameController,
                decoration: const InputDecoration(labelText: 'Area Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
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
