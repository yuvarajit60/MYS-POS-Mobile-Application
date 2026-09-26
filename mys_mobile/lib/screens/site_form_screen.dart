import 'package:flutter/material.dart';
import '../models/area.dart';
import '../models/city.dart';
import '../models/site_detail.dart';
import '../services/area_service.dart';
import '../services/city_service.dart';
import '../services/site_service.dart';
import 'area_form_screen.dart';
import 'widgets/search_picker_sheet.dart';

/// Add-or-edit form for a Site — bare SiteName/Area/City, no customer.
/// Which customer (if any) a site belongs to is owned by the separate
/// "Customer Site Mapping" master (see manage_customer_site_mappings_screen.dart),
/// not this screen.
class SiteFormScreen extends StatefulWidget {
  final SiteDetail? editing;
  const SiteFormScreen({super.key, this.editing});

  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _siteNameController = TextEditingController(text: widget.editing?.siteName);
  final _siteService = SiteService();
  final _cityService = CityService();
  final _areaService = AreaService();

  City? _selectedCity;
  Area? _selectedArea;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedCity = City(cityId: editing.cityId, cityName: editing.cityName);
      if (editing.areaId > 0) {
        _selectedArea = Area(areaId: editing.areaId, areaName: editing.areaName, cityId: editing.cityId, cityName: editing.cityName);
      }
    }
  }

  Future<void> _pickCity() async {
    final city = await showSearchPicker<City>(
      context: context,
      title: 'Search city',
      search: _cityService.search,
      itemLabel: (c) => c.cityName,
    );
    if (city == null) return;
    setState(() {
      _selectedCity = city;
      _selectedArea = null;
    });
  }

  Future<void> _pickArea() async {
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a city first.')));
      return;
    }

    final area = await showSearchPicker<Area>(
      context: context,
      title: 'Search area',
      search: (query) => _areaService.search(query, cityId: _selectedCity!.cityId),
      itemLabel: (a) => a.areaName,
      addNewLabel: 'Add New Area',
      onAddNew: (context) => Navigator.of(context).push<Area>(
        MaterialPageRoute(builder: (_) => AreaFormScreen(initialCity: _selectedCity)),
      ),
    );
    if (area != null) setState(() => _selectedArea = area);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a city.')));
      return;
    }
    if (_selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an area.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final siteName = _siteNameController.text.trim();

      final site = _isEditing
          ? await _siteService.update(
              siteId: widget.editing!.siteId,
              siteName: siteName,
              area: _selectedArea!,
            )
          : await _siteService.create(
              siteName: siteName,
              area: _selectedArea!,
            );
      if (!mounted) return;
      Navigator.of(context).pop<SiteDetail>(site);
    } on SiteServiceException catch (e) {
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
        title: const Text('Delete site?'),
        content: Text('Delete "${widget.editing!.siteName}"? This cannot be undone from the app.'),
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
      await _siteService.delete(widget.editing!.siteId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on SiteServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Site' : 'Add New Site'),
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
                controller: _siteNameController,
                decoration: const InputDecoration(labelText: 'Site Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
              InkWell(
                onTap: _pickArea,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Area'),
                  child: Text(_selectedArea?.areaName ?? 'Tap to select an area'),
                ),
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
