import 'dart:async';
import 'package:flutter/material.dart';

/// Web equivalent of mobile's showSearchPicker (search_picker_sheet.dart)
/// — a centered modal dialog instead of a full-height bottom sheet, to
/// match the web app's own dialog-based forms (see HeadFormDialog). Shared
/// by every web form that needs to pick from another master (Customer,
/// Site, Product Group, Brand, Type, Employee, Vehicle, ...).
Future<T?> showWebSearchPicker<T>({
  required BuildContext context,
  required String title,
  required Future<List<T>> Function(String query) search,
  required String Function(T item) itemLabel,
  String Function(T item)? itemSubtitle,
  String? addNewLabel,
  Future<T?> Function(BuildContext context)? onAddNew,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => _WebSearchPickerDialog<T>(
      title: title,
      search: search,
      itemLabel: itemLabel,
      itemSubtitle: itemSubtitle,
      addNewLabel: addNewLabel,
      onAddNew: onAddNew,
    ),
  );
}

class _WebSearchPickerDialog<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function(String query) search;
  final String Function(T item) itemLabel;
  final String Function(T item)? itemSubtitle;
  final String? addNewLabel;
  final Future<T?> Function(BuildContext context)? onAddNew;

  const _WebSearchPickerDialog({
    required this.title,
    required this.search,
    required this.itemLabel,
    this.itemSubtitle,
    this.addNewLabel,
    this.onAddNew,
  });

  @override
  State<_WebSearchPickerDialog<T>> createState() => _WebSearchPickerDialogState<T>();
}

class _WebSearchPickerDialogState<T> extends State<_WebSearchPickerDialog<T>> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<T> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    try {
      final results = await widget.search(query);
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

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleAddNew() async {
    final created = await widget.onAddNew!(context);
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final canAddNew = widget.addNewLabel != null && widget.onAddNew != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.title,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: _onChanged,
              ),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              Flexible(
                child: _results.isEmpty && !_loading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('No results'),
                              if (canAddNew) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _handleAddNew,
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: Text(widget.addNewLabel!),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            title: Text(widget.itemLabel(item)),
                            subtitle: widget.itemSubtitle != null ? Text(widget.itemSubtitle!(item)) : null,
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
