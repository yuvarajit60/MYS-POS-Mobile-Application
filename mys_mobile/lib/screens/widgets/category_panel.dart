import 'package:flutter/material.dart';
import 'action_item.dart';

/// A colored dashboard card: title/subtitle + a small header icon, a 3-column
/// grid of mini tiles, and an optional "View All" link. Used for the Entry/
/// Report (and Master, on the More tab) sections — [accentColor] drives the
/// header icon, title color, and each tile's icon color; [backgroundColor]
/// is the panel's light wash.
class CategoryPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData headerIcon;
  final Color accentColor;
  final Color backgroundColor;
  final List<ActionItem> items;
  final VoidCallback? onViewAll;

  const CategoryPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.headerIcon,
    required this.accentColor,
    required this.backgroundColor,
    required this.items,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: accentColor, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(headerIcon, color: accentColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: [for (final item in items) _MiniTile(item: item, accentColor: accentColor)],
          ),
          if (onViewAll != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View All', style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 13)),
                    Icon(Icons.chevron_right, color: accentColor, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  final ActionItem item;
  final Color accentColor;

  const _MiniTile({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Icon(item.icon, color: accentColor, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
