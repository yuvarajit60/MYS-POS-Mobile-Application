import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../widgets/product_form_dialog.dart';

/// Web-only Product master screen — same search/table/dialog pattern as
/// HeadMasterWebScreen. Same ProductService/Product model as mobile.
class ProductMasterWebScreen extends StatefulWidget {
  const ProductMasterWebScreen({super.key});

  @override
  State<ProductMasterWebScreen> createState() => _ProductMasterWebScreenState();
}

class _ProductMasterWebScreenState extends State<ProductMasterWebScreen> {
  final _productService = ProductService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Product> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    try {
      final results = await _productService.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addNew() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => const ProductFormDialog());
    if (saved == true) _runSearch(_searchController.text);
  }

  Future<void> _edit(Product product) async {
    try {
      final detail = await _productService.getById(product.productId);
      if (!mounted) return;
      final saved = await showDialog<bool>(context: context, builder: (_) => ProductFormDialog(editing: detail));
      if (saved == true) _runSearch(_searchController.text);
    } on ProductServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete "${product.productName}"? This cannot be undone.'),
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

    try {
      await _productService.delete(product.productId);
      _runSearch(_searchController.text);
    } on ProductServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MysColors.bgLight,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search product name',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: _onChanged,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addNew,
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: _results.isEmpty && !_loading
                  ? const Center(child: Text('No products found.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(MysColors.bgLight),
                        columns: const [
                          DataColumn(label: Text('Product Name')),
                          DataColumn(label: Text('Rate'), numeric: true),
                          DataColumn(label: Text('CGST %'), numeric: true),
                          DataColumn(label: Text('SGST %'), numeric: true),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          for (final product in _results)
                            DataRow(
                              cells: [
                                DataCell(Text(product.productName)),
                                DataCell(Text(product.rate.toStringAsFixed(2))),
                                DataCell(Text(product.salesCgstPercentage.toStringAsFixed(2))),
                                DataCell(Text(product.salesSgstPercentage.toStringAsFixed(2))),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Edit',
                                      onPressed: () => _edit(product),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Delete',
                                      onPressed: () => _delete(product),
                                    ),
                                  ],
                                )),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
