import 'package:flutter/material.dart';
import '../../models/brand.dart';
import '../../models/product.dart';
import '../../models/product_detail.dart';
import '../../models/product_group.dart';
import '../../models/product_type.dart';
import '../../services/brand_service.dart';
import '../../services/product_group_service.dart';
import '../../services/product_service.dart';
import '../../services/product_type_service.dart';
import 'web_search_picker.dart';

/// See product_form_screen.dart (mobile) for the same fields/logic as a
/// field-by-field push screen; this is the web equivalent as a modal
/// dialog (see HeadFormDialog).
class ProductFormDialog extends StatefulWidget {
  final ProductDetail? editing;
  const ProductFormDialog({super.key, this.editing});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.editing?.productName);
  late final _mrpController = TextEditingController(text: widget.editing?.mrp.toString());
  late final _gstController = TextEditingController(text: widget.editing?.salesGstPercentage.toString());
  final _productService = ProductService();
  final _productGroupService = ProductGroupService();
  final _brandService = BrandService();
  final _typeService = ProductTypeService();

  ProductGroup? _selectedGroup;
  Brand? _selectedBrand;
  ProductType? _selectedType;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedGroup = ProductGroup(productGroupId: editing.productGroupId, productGroupName: editing.productGroupName);
      _selectedBrand = Brand(brandId: editing.brandId, brandName: editing.brandName);
      _selectedType = ProductType(typeId: editing.typeId, typeName: editing.typeName);
    }
  }

  Future<void> _pickGroup() async {
    final group = await showWebSearchPicker<ProductGroup>(
      context: context,
      title: 'Search product group',
      search: _productGroupService.search,
      itemLabel: (g) => g.productGroupName,
    );
    if (group != null) setState(() => _selectedGroup = group);
  }

  Future<void> _pickBrand() async {
    final brand = await showWebSearchPicker<Brand>(
      context: context,
      title: 'Search brand',
      search: _brandService.search,
      itemLabel: (b) => b.brandName,
    );
    if (brand != null) setState(() => _selectedBrand = brand);
  }

  Future<void> _pickType() async {
    final type = await showWebSearchPicker<ProductType>(
      context: context,
      title: 'Search type',
      search: _typeService.search,
      itemLabel: (t) => t.typeName,
    );
    if (type != null) setState(() => _selectedType = type);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroup == null || _selectedBrand == null || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product group, brand, and type.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final productName = _nameController.text.trim();
      final mrp = double.parse(_mrpController.text.trim());
      final gst = double.parse(_gstController.text.trim());

      final product = _isEditing
          ? await _productService.update(
              productId: widget.editing!.productId,
              productName: productName,
              mrp: mrp,
              productGroup: _selectedGroup!,
              brand: _selectedBrand!,
              type: _selectedType!,
              salesGstPercentage: gst,
            )
          : await _productService.create(
              productName: productName,
              mrp: mrp,
              productGroup: _selectedGroup!,
              brand: _selectedBrand!,
              type: _selectedType!,
              salesGstPercentage: gst,
            );
      if (!mounted) return;
      Navigator.of(context).pop<Product>(product);
    } on ProductServiceException catch (e) {
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
        title: const Text('Delete product?'),
        content: Text('Delete "${widget.editing!.productName}"? This cannot be undone.'),
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
      await _productService.delete(widget.editing!.productId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ProductServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mrpController.dispose();
    _gstController.dispose();
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
                        _isEditing ? 'Edit Product' : 'Add New Product',
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
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mrpController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'MRP'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return double.tryParse(v.trim()) == null ? 'Enter a valid number' : null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickGroup,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Product Group'),
                    child: Text(_selectedGroup?.productGroupName ?? 'Click to select a product group'),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickBrand,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Brand'),
                    child: Text(_selectedBrand?.brandName ?? 'Click to select a brand'),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickType,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Type'),
                    child: Text(_selectedType?.typeName ?? 'Click to select a type'),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gstController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Sales GST %',
                    helperText: 'Total GST — split evenly into CGST + SGST',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return double.tryParse(v.trim()) == null ? 'Enter a valid number' : null;
                  },
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
