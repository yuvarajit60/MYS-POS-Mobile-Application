import 'package:flutter/material.dart';

/// One tappable shortcut shown in a [CategoryPanel] grid or the quick-create
/// sheet — just enough to describe a menu entry generically.
class ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ActionItem({required this.icon, required this.label, required this.onTap});
}
