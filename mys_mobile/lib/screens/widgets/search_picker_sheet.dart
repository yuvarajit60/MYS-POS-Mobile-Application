import 'dart:async';
import 'package:flutter/material.dart';

/// Generic bottom-sheet search picker, shared by the customer and product
/// pickers on the Create Sales Order screen. Debounces input and re-queries
/// [search] as the user types. If [addNewLabel]/[onAddNew] are supplied, an
/// "add new" action is offered only when the current search has no matches
/// — tapping it runs [onAddNew] (typically pushing a create-record screen);
/// if that returns a non-null item, the sheet closes with that item as the
/// picked result.
Future<T?> showSearchPicker<T>({
  required BuildContext context,
  required String title,
  required Future<List<T>> Function(String query) search,
  required String Function(T item) itemLabel,
  String Function(T item)? itemSubtitle,
  String? addNewLabel,
  Future<T?> Function(BuildContext context)? onAddNew,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SearchPickerSheet<T>(
      title: title,
      search: search,
      itemLabel: itemLabel,
      itemSubtitle: itemSubtitle,
      addNewLabel: addNewLabel,
      onAddNew: onAddNew,
    ),
  );
}

class _SearchPickerSheet<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function(String query) search;
  final String Function(T item) itemLabel;
  final String Function(T item)? itemSubtitle;
  final String? addNewLabel;
  final Future<T?> Function(BuildContext context)? onAddNew;

  const _SearchPickerSheet({
    required this.title,
    required this.search,
    required this.itemLabel,
    this.itemSubtitle,
    this.addNewLabel,
    this.onAddNew,
  });

  @override
  State<_SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<_SearchPickerSheet<T>> {
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

  Future<void> _handleAddNew() async {
    final created = await widget.onAddNew!(context);
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAddNew = widget.addNewLabel != null && widget.onAddNew != null;

    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // Shrink the sheet by the keyboard's height instead of just padding for
    // it — otherwise (height + bottom padding) exceeds the screen and the
    // sheet gets pushed off the top edge while the keyboard is open.
    final sheetHeight = (screenHeight * 0.75 - keyboardHeight).clamp(screenHeight * 0.4, screenHeight * 0.75);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.title,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onChanged,
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _results.isEmpty && !_loading
                  ? Center(
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
                    )
                  : ListView.builder(
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
    );
  }
}
