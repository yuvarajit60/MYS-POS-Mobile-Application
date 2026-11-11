import 'package:flutter/material.dart';
import '../../models/area.dart';
import '../../models/site_detail.dart';
import '../../services/area_service.dart';
import '../../services/site_service.dart';
import 'web_search_picker.dart';

/// Web equivalent of site_form_screen.dart (mobile) — Site Name + Area
/// only; Customer mapping is a separate master (Customer Site Mapping),
/// same as mobile.
class SiteFormDialog extends StatefulWidget {
  final SiteDetail? editing;
  const SiteFormDialog({super.key, this.editing});

  @override
  State<SiteFormDialog> createState() => _SiteFormDialogState();
}

class _SiteFormDialogState extends State<SiteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.editing?.siteName);
  final _siteService = SiteService();
  final _areaService = AreaService();

  Area? _selectedArea;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedArea = Area(areaId: editing.areaId, areaName: editing.areaName, cityId: editing.cityId, cityName: editing.cityName);
    }
  }

  Future<void> _pickArea() async {
    final area = await showWebSearchPicker<Area>(
      context: context,
      title: 'Search area',
      search: _areaService.search,
      itemLabel: (a) => a.areaName,
    );
    if (area != null) setState(() => _selectedArea = area);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an area.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final siteName = _nameController.text.trim();

      final site = _isEditing
          ? await _siteService.update(siteId: widget.editing!.siteId, siteName: siteName, area: _selectedArea!)
          : await _siteService.create(siteName: siteName, area: _selectedArea!);
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
        content: Text('Delete "${widget.editing!.siteName}"? This cannot be undone.'),
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
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
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
                        _isEditing ? 'Edit Site' : 'Add New Site',
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
                      onPressed: busy ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Site Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickArea,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Area'),
                    child: Text(_selectedArea?.areaName ?? 'Click to select an area'),
                  ),
                ),
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
