import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/session.dart';
import 'create_delivery_screen.dart';
import 'create_sales_order_screen.dart';
import 'create_trip_entry_screen.dart';
import 'delivery_reports_screen.dart';
import 'login_screen.dart';
import 'manage_customers_screen.dart';
import 'manage_products_screen.dart';
import 'manage_sites_screen.dart';
import 'manage_vehicle_mappings_screen.dart';
import 'reports_screen.dart';
import 'trip_entry_reports_screen.dart';
import 'widgets/action_item.dart';
import 'widgets/category_panel.dart';
import 'widgets/mys_app_bar_title.dart';

/// Non-driver home shell: bottom nav (Home / Entries / [+] / Reports / More)
/// with a center-docked FAB for quick-create, matching the reference
/// screenshots. Driver logins never reach this screen — LandingScreen keeps
/// its own single-tile branch for them.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  Future<void> _logout(BuildContext context) async {
    await Session.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  List<ActionItem> _entryItems(BuildContext context) => [
        ActionItem(
          icon: Icons.add_shopping_cart,
          label: 'Sales Order',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateSalesOrderScreen())),
        ),
        ActionItem(
          icon: Icons.local_shipping_outlined,
          label: 'Trip Entry',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateTripEntryScreen())),
        ),
        ActionItem(
          icon: Icons.local_shipping,
          label: 'Delivery Entry',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateDeliveryScreen())),
        ),
      ];

  List<ActionItem> _reportItems(BuildContext context) => [
        ActionItem(
          icon: Icons.assessment_outlined,
          label: 'Sales Order Report',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportsScreen())),
        ),
        ActionItem(
          icon: Icons.receipt_long_outlined,
          label: 'Trip Entry Report',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TripEntryReportsScreen())),
        ),
        ActionItem(
          icon: Icons.fact_check_outlined,
          label: 'Delivery Report',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeliveryReportsScreen())),
        ),
      ];

  List<ActionItem> _masterItems(BuildContext context) => [
        ActionItem(
          icon: Icons.inventory_2_outlined,
          label: 'Product',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageProductsScreen())),
        ),
        ActionItem(
          icon: Icons.people_alt_outlined,
          label: 'Customer',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageCustomersScreen())),
        ),
        ActionItem(
          icon: Icons.location_on_outlined,
          label: 'Site',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageSitesScreen())),
        ),
        ActionItem(
          icon: Icons.directions_car_outlined,
          label: 'Vehicle Mapping',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageVehicleMappingsScreen())),
        ),
      ];

  void _openQuickCreate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quick Create', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: MysColors.navy800)),
              const SizedBox(height: 16),
              for (final item in _entryItems(context))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: MysColors.green500, child: Icon(item.icon, color: Colors.white, size: 20)),
                  title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    item.onTap();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(
        entryItems: _entryItems(context),
        reportItems: _reportItems(context),
        onViewAllEntries: () => setState(() => _selectedIndex = 1),
        onViewAllReports: () => setState(() => _selectedIndex = 2),
      ),
      _SectionTab(
        title: 'Entries',
        subtitle: 'Create and manage your business',
        headerIcon: Icons.edit_note,
        accentColor: MysColors.green600,
        backgroundColor: MysColors.green500.withValues(alpha: 0.10),
        items: _entryItems(context),
      ),
      _SectionTab(
        title: 'Reports',
        subtitle: 'View and analyze your business',
        headerIcon: Icons.bar_chart,
        accentColor: MysColors.navy800,
        backgroundColor: MysColors.navy900.withValues(alpha: 0.08),
        items: _reportItems(context),
      ),
      _MoreTab(masterItems: _masterItems(context), onLogout: () => _logout(context)),
    ];

    const titles = ['Home', 'Entries', 'Reports', 'More'];

    return Scaffold(
      appBar: AppBar(
        title: _selectedIndex == 0 ? const MysAppBarTitle() : Text(titles[_selectedIndex]),
        toolbarHeight: 68,
      ),
      body: SafeArea(child: pages[_selectedIndex]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: MysColors.green500,
        onPressed: () => _openQuickCreate(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavButton(icon: Icons.home_outlined, label: 'Home', selected: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
            _NavButton(icon: Icons.edit_note, label: 'Entries', selected: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
            const SizedBox(width: 40),
            _NavButton(icon: Icons.bar_chart, label: 'Reports', selected: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
            _NavButton(icon: Icons.more_horiz, label: 'More', selected: _selectedIndex == 3, onTap: () => setState(() => _selectedIndex = 3)),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? MysColors.green600 : Colors.black45;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final List<ActionItem> entryItems;
  final List<ActionItem> reportItems;
  final VoidCallback onViewAllEntries;
  final VoidCallback onViewAllReports;

  const _HomeTab({
    required this.entryItems,
    required this.reportItems,
    required this.onViewAllEntries,
    required this.onViewAllReports,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroBanner(),
          const SizedBox(height: 16),
          CategoryPanel(
            title: 'ENTRY',
            subtitle: 'Create and manage your business',
            headerIcon: Icons.edit_note,
            accentColor: MysColors.green600,
            backgroundColor: MysColors.green500.withValues(alpha: 0.10),
            items: entryItems,
            onViewAll: onViewAllEntries,
          ),
          const SizedBox(height: 16),
          CategoryPanel(
            title: 'REPORTS',
            subtitle: 'View and analyze your business',
            headerIcon: Icons.bar_chart,
            accentColor: MysColors.navy800,
            backgroundColor: MysColors.navy900.withValues(alpha: 0.08),
            items: reportItems,
            onViewAll: onViewAllReports,
          ),
        ],
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData headerIcon;
  final Color accentColor;
  final Color backgroundColor;
  final List<ActionItem> items;

  const _SectionTab({
    required this.title,
    required this.subtitle,
    required this.headerIcon,
    required this.accentColor,
    required this.backgroundColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: CategoryPanel(
        title: title,
        subtitle: subtitle,
        headerIcon: headerIcon,
        accentColor: accentColor,
        backgroundColor: backgroundColor,
        items: items,
      ),
    );
  }
}

class _MoreTab extends StatelessWidget {
  final List<ActionItem> masterItems;
  final VoidCallback onLogout;

  const _MoreTab({required this.masterItems, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CategoryPanel(
            title: 'MASTER',
            subtitle: 'Manage reference data',
            headerIcon: Icons.dashboard_customize_outlined,
            accentColor: MysColors.navy800,
            backgroundColor: MysColors.bgLight,
            items: masterItems,
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

/// Same banner used previously on the plain landing page.
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MysColors.navy900, MysColors.navy800],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: const BoxDecoration(color: MysColors.green500, shape: BoxShape.circle),
            child: const Icon(Icons.storefront, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Home',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up, color: MysColors.green400, size: 22),
        ],
      ),
    );
  }
}
