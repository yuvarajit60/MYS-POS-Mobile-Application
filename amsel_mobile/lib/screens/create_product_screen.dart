import 'package:flutter/material.dart';
import '../models/brand.dart';
import '../models/product.dart';
import '../models/product_group.dart';
import '../models/product_type.dart';
import '../services/brand_service.dart';
import '../services/product_group_service.dart';
import '../services/product_service.dart';
import '../services/product_type_service.dart';
import 'widgets/search_picker_sheet.dart';

/// Quick "add a product on the spot" form for field sales reps. Creates the
/// product in both dbo.PRODUCT and dbo.PRODUCT_DETAILS (kept in sync).
/// Returns the newly created Product via Navigator.pop so callers (landing
/// page or the product search picker) can use it immediately.
class CreateProductScreen extends StatefulWidget {
  const CreateProductScreen({super.key});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mrpController = TextEditingController();
  final _gstController = TextEditingController();
  final _productService = ProductService();
  final _productGroupService = ProductGroupService();
  final _brandService = BrandService();
  final _typeService = ProductTypeService();

  ProductGroup? _selectedGroup;
  Brand? _selectedBrand;
  ProductType? _selectedType;
  bool _saving = false;

  Future<void> _pickGroup() async {
    final group = await showSearchPicker<ProductGroup>(
      context: context,
      title: 'Search product group',
      search: _productGroupService.search,
      itemLabel: (g) => g.productGroupName,
    );
    if (group != null) setState(() => _selectedGroup = group);
  }

  Future<void> _pickBrand() async {
    final brand = await showSearchPicker<Brand>(
      context: context,
      title: 'Search brand',
      search: _brandService.search,
      itemLabel: (b) => b.brandName,
    );
    if (brand != null) setState(() => _selectedBrand = brand);
  }

  Future<void> _pickType() async {
    final type = await showSearchPicker<ProductType>(
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
      final product = await _productService.create(
        productName: _nameController.text.trim(),
        mrp: double.parse(_mrpController.text.trim()),
        productGroup: _selectedGroup!,
        brand: _selectedBrand!,
        type: _selectedType!,
        salesGstPercentage: double.parse(_gstController.text.trim()),
      );
      if (!mounted) return;
      Navigator.of(context).pop<Product>(product);
    } on ProductServiceException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mrpController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'MRP', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return double.tryParse(v.trim()) == null ? 'Enter a valid number' : null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickGroup,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Product Group'),
                  child: Text(_selectedGroup?.productGroupName ?? 'Tap to select a product group'),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickBrand,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Brand'),
                  child: Text(_selectedBrand?.brandName ?? 'Tap to select a brand'),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickType,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Type'),
                  child: Text(_selectedType?.typeName ?? 'Tap to select a type'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gstController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Sales GST %',
                  helperText: 'Total GST — split evenly into CGST + SGST',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return double.tryParse(v.trim()) == null ? 'Enter a valid number' : null;
                },
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
      ),
    );
  }
}
