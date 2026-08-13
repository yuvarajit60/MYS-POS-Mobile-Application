import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/sales_order_line.dart';
import '../services/customer_service.dart';
import '../services/product_service.dart';
import '../services/sales_order_service.dart';
import 'customer_form_screen.dart';
import 'product_form_screen.dart';
import 'widgets/line_items_grid.dart';
import 'widgets/search_picker_sheet.dart';

class CreateSalesOrderScreen extends StatefulWidget {
  const CreateSalesOrderScreen({super.key});

  @override
  State<CreateSalesOrderScreen> createState() => _CreateSalesOrderScreenState();
}

class _CreateSalesOrderScreenState extends State<CreateSalesOrderScreen> {
  final _customerService = CustomerService();
  final _productService = ProductService();
  final _salesOrderService = SalesOrderService();

  final _shippingAddressController = TextEditingController();
  Customer? _selectedCustomer;
  final List<SalesOrderLine> _lines = [];
  bool _saving = false;

  double get _grandTotal => _lines.fold(0, (sum, line) => sum + line.totalAmount);

  // Matches the backend's rounding: the saved order's NETAMOUNT is rounded
  // to the nearest whole rupee, with the difference stored as ROUNDOFF.
  double get _roundedGrandTotal => _grandTotal.roundToDouble();

  Future<void> _pickCustomer() async {
    final customer = await showSearchPicker<Customer>(
      context: context,
      title: 'Search customer name or mobile number',
      search: _customerService.search,
      itemLabel: (c) => c.customerName,
      itemSubtitle: (c) => c.mobileNo,
      addNewLabel: 'Add New Customer',
      onAddNew: (context) => Navigator.of(context).push<Customer>(
        MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
      ),
    );
    if (customer != null) setState(() => _selectedCustomer = customer);
  }

  Future<void> _addProduct() async {
    if (_selectedCustomer == null) {
      _showMessage('Select a customer first.');
      return;
    }

    final product = await showSearchPicker<Product>(
      context: context,
      title: 'Search product',
      search: _productService.search,
      itemLabel: (p) => p.productName,
      itemSubtitle: (p) => 'MRP: ${p.rate.toStringAsFixed(2)}',
      addNewLabel: 'Add New Product',
      onAddNew: (context) => Navigator.of(context).push<Product>(
        MaterialPageRoute(builder: (_) => const ProductFormScreen()),
      ),
    );
    if (product == null) return;

    setState(() {
      final existingIndex = _lines.indexWhere((l) => l.product.productId == product.productId);
      if (existingIndex >= 0) {
        _lines[existingIndex].qty += 1;
      } else {
        _lines.add(SalesOrderLine(product: product));
      }
    });
  }

  void _onQtyChanged(int index, double newQty) {
    setState(() => _lines[index].qty = newQty);
  }

  void _onRateChanged(int index, double newRate) {
    setState(() => _lines[index].rate = newRate);
  }

  void _onDeleteLine(int index) {
    setState(() => _lines.removeAt(index));
  }

  Future<void> _saveAndClose() async {
    if (_selectedCustomer == null) {
      _showMessage('Select a customer first.');
      return;
    }
    if (_lines.isEmpty) {
      _showMessage('Add at least one product.');
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await _salesOrderService.create(
        customer: _selectedCustomer!,
        shippingAddress: _shippingAddressController.text.trim(),
        lines: _lines,
      );
      if (!mounted) return;
      _showMessage('Sales order ${result.entryNo} saved.');
      Navigator.of(context).pop();
    } on SalesOrderException catch (e) {
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
    _shippingAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Sales Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Customer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickCustomer,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Customer'),
                child: Text(
                  _selectedCustomer == null
                      ? 'Tap to select a customer'
                      : '${_selectedCustomer!.customerName}  (${_selectedCustomer!.mobileNo})',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _shippingAddressController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Site Delivery', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Products', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _selectedCustomer == null ? null : _addProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
              ],
            ),
            LineItemsGrid(
              lines: _lines,
              onQtyChanged: _onQtyChanged,
              onRateChanged: _onRateChanged,
              onDelete: _onDeleteLine,
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(_roundedGrandTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _saveAndClose,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving ? const CircularProgressIndicator() : const Text('Save and Close'),
            ),
          ],
        ),
      ),
    );
  }
}
