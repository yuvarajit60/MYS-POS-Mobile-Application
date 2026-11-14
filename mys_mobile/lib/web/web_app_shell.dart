import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/company_provider.dart';
import '../core/session.dart';
import '../core/web_layout_mode.dart';
import '../screens/login_screen.dart';
import 'screens/area_master_web_screen.dart';
import 'screens/cancel_entry_web_screen.dart';
import 'screens/customer_master_web_screen.dart';
import 'screens/customer_site_mapping_web_screen.dart';
import 'screens/delivery_entry_web_screen.dart';
import 'screens/delivery_report_web_screen.dart';
import 'screens/employee_master_web_screen.dart';
import 'screens/head_master_web_screen.dart';
import 'screens/home_web_screen.dart';
import 'screens/income_expense_entry_web_screen.dart';
import 'screens/income_expense_report_web_screen.dart';
import 'screens/ledger_report_web_screen.dart';
import 'screens/payment_entry_web_screen.dart';
import 'screens/payment_report_web_screen.dart';
import 'screens/product_master_web_screen.dart';
import 'screens/sales_entry_web_screen.dart';
import 'screens/sales_order_entry_web_screen.dart';
import 'screens/sales_order_report_web_screen.dart';
import 'screens/sales_report_web_screen.dart';
import 'screens/site_master_web_screen.dart';
import 'screens/trip_entry_report_web_screen.dart';
import 'screens/trip_entry_web_screen.dart';
import 'screens/vehicle_mapping_web_screen.dart';

/// The web app's own shell — sidebar + top bar — deliberately not a reuse
/// of MainShellScreen's phone-style bottom nav (see main.dart's
/// _PhoneFrame comment). A conventional admin-dashboard layout (sidebar
/// nav grouped by section, a content area, a top bar for page title +
/// logout) inspired by the desktop app's Masters/Transactions/Reports
/// grouping but styled as a modern web app, not a copy of either the
/// desktop or mobile screens. Every master screen here is still backed by
/// the exact same service/model as its mobile counterpart — only the
/// presentation (data table + modal dialog instead of list + pushed
/// screen) differs.
class WebAppShell extends StatefulWidget {
  const WebAppShell({super.key});

  @override
  State<WebAppShell> createState() => _WebAppShellState();
}

enum _WebSection {
  home,
  product,
  customer,
  site,
  customerSiteMapping,
  area,
  vehicleMapping,
  employee,
  headMaster,
  salesOrder,
  delivery,
  tripEntry,
  payment,
  salesEntry,
  incomeExpense,
  cancelEntry,
  salesOrderReport,
  salesReport,
  tripEntryReport,
  deliveryReport,
  customerLedger,
  paymentReport,
  incomeExpenseReport,
}

/// Single source of truth for each section's icon — read by both the
/// sidebar nav items and the page-title bar, so the title bar always shows
/// the icon matching whichever section is actually selected instead of a
/// generic one.
const Map<_WebSection, IconData> _sectionIcons = {
  _WebSection.home: Icons.home_outlined,
  _WebSection.salesOrder: Icons.description_outlined,
  _WebSection.tripEntry: Icons.local_shipping_outlined,
  _WebSection.delivery: Icons.local_shipping,
  _WebSection.payment: Icons.payments_outlined,
  _WebSection.cancelEntry: Icons.cancel_outlined,
  _WebSection.salesEntry: Icons.fact_check_outlined,
  _WebSection.incomeExpense: Icons.account_balance_wallet_outlined,
  _WebSection.salesOrderReport: Icons.description_outlined,
  _WebSection.salesReport: Icons.receipt_long_outlined,
  _WebSection.tripEntryReport: Icons.local_shipping_outlined,
  _WebSection.deliveryReport: Icons.local_shipping,
  _WebSection.customerLedger: Icons.account_balance_outlined,
  _WebSection.paymentReport: Icons.payments_outlined,
  _WebSection.incomeExpenseReport: Icons.account_balance_wallet_outlined,
  _WebSection.product: Icons.inventory_2_outlined,
  _WebSection.customer: Icons.people_alt_outlined,
  _WebSection.site: Icons.location_on_outlined,
  _WebSection.customerSiteMapping: Icons.link_outlined,
  _WebSection.area: Icons.map_outlined,
  _WebSection.vehicleMapping: Icons.directions_car_outlined,
  _WebSection.employee: Icons.badge_outlined,
  _WebSection.headMaster: Icons.account_balance_wallet_outlined,
};

String _titleFor(_WebSection section) {
  switch (section) {
    case _WebSection.home:
      return 'Home';
    case _WebSection.product:
      return 'Product';
    case _WebSection.customer:
      return 'Customer';
    case _WebSection.site:
      return 'Site';
    case _WebSection.customerSiteMapping:
      return 'Customer Site Mapping';
    case _WebSection.area:
      return 'Area';
    case _WebSection.vehicleMapping:
      return 'Vehicle Mapping';
    case _WebSection.employee:
      return 'Employee';
    case _WebSection.headMaster:
      return 'Head Master';
    case _WebSection.salesOrder:
      return 'Sales Order';
    case _WebSection.delivery:
      return 'Delivery Entry';
    case _WebSection.tripEntry:
      return 'Trip Entry';
    case _WebSection.payment:
      return 'Payment Entry';
    case _WebSection.salesEntry:
      return 'Sales Entry';
    case _WebSection.incomeExpense:
      return 'Income or Expenses';
    case _WebSection.cancelEntry:
      return 'Cancel Entry';
    case _WebSection.salesOrderReport:
      return 'Sales Order Report';
    case _WebSection.salesReport:
      return 'Sales Report';
    case _WebSection.tripEntryReport:
      return 'Trip Entry Report';
    case _WebSection.deliveryReport:
      return 'Delivery Report';
    case _WebSection.customerLedger:
      return 'Customer Ledger';
    case _WebSection.paymentReport:
      return 'Payment Report';
    case _WebSection.incomeExpenseReport:
      return 'Income and Expenses Report';
  }
}

class _WebAppShellState extends State<WebAppShell> {
  /// Sections currently open as tabs, in the order they were opened. Home
  /// is always implicitly available and never appears here — it's the
  /// permanent first tab and can't be closed.
  final List<_WebSection> _openTabs = [];
  _WebSection _active = _WebSection.home;
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    CompanyProvider.instance.ensureLoaded();
    WebLayoutMode.fullWidth.value = true;
  }

  @override
  void dispose() {
    WebLayoutMode.fullWidth.value = false;
    super.dispose();
  }

  Future<void> _logout() async {
    await Session.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Sidebar click: switch to this section's tab, opening one first if it
  /// isn't already open. Re-clicking an already-open section just brings
  /// its existing tab (and whatever it was left mid-fill) back to front.
  void _openSection(_WebSection section) {
    setState(() {
      if (section != _WebSection.home && !_openTabs.contains(section)) {
        _openTabs.add(section);
      }
      _active = section;
    });
  }

  /// Tab's close button, or an entry screen's own Close button (which
  /// forwards to this via onClose). Falls back to the tab that was to its
  /// left, or Home once no tabs are left.
  void _closeTab(_WebSection section) {
    setState(() {
      final index = _openTabs.indexOf(section);
      if (index == -1) return;
      _openTabs.removeAt(index);
      if (_active == section) {
        _active = _openTabs.isEmpty ? _WebSection.home : _openTabs[index == 0 ? 0 : index - 1];
      }
    });
  }

  Widget _contentFor(_WebSection section) {
    switch (section) {
      case _WebSection.home:
        return const HomeWebScreen(key: ValueKey(_WebSection.home));
      case _WebSection.product:
        return const ProductMasterWebScreen(key: ValueKey(_WebSection.product));
      case _WebSection.customer:
        return const CustomerMasterWebScreen(key: ValueKey(_WebSection.customer));
      case _WebSection.site:
        return const SiteMasterWebScreen(key: ValueKey(_WebSection.site));
      case _WebSection.customerSiteMapping:
        return const CustomerSiteMappingWebScreen(key: ValueKey(_WebSection.customerSiteMapping));
      case _WebSection.area:
        return const AreaMasterWebScreen(key: ValueKey(_WebSection.area));
      case _WebSection.vehicleMapping:
        return const VehicleMappingWebScreen(key: ValueKey(_WebSection.vehicleMapping));
      case _WebSection.employee:
        return const EmployeeMasterWebScreen(key: ValueKey(_WebSection.employee));
      case _WebSection.headMaster:
        return const HeadMasterWebScreen(key: ValueKey(_WebSection.headMaster));
      case _WebSection.salesOrder:
        return SalesOrderEntryWebScreen(key: const ValueKey(_WebSection.salesOrder), onClose: () => _closeTab(section));
      case _WebSection.delivery:
        return const DeliveryEntryWebScreen(key: ValueKey(_WebSection.delivery));
      case _WebSection.tripEntry:
        return TripEntryWebScreen(key: const ValueKey(_WebSection.tripEntry), onClose: () => _closeTab(section));
      case _WebSection.payment:
        return const PaymentEntryWebScreen(key: ValueKey(_WebSection.payment));
      case _WebSection.salesEntry:
        return SalesEntryWebScreen(key: const ValueKey(_WebSection.salesEntry), onClose: () => _closeTab(section));
      case _WebSection.incomeExpense:
        return const IncomeExpenseEntryWebScreen(key: ValueKey(_WebSection.incomeExpense));
      case _WebSection.cancelEntry:
        return const CancelEntryWebScreen(key: ValueKey(_WebSection.cancelEntry));
      case _WebSection.salesOrderReport:
        return const SalesOrderReportWebScreen(key: ValueKey(_WebSection.salesOrderReport));
      case _WebSection.salesReport:
        return const SalesReportWebScreen(key: ValueKey(_WebSection.salesReport));
      case _WebSection.tripEntryReport:
        return const TripEntryReportWebScreen(key: ValueKey(_WebSection.tripEntryReport));
      case _WebSection.deliveryReport:
        return const DeliveryReportWebScreen(key: ValueKey(_WebSection.deliveryReport));
      case _WebSection.customerLedger:
        return const LedgerReportWebScreen(key: ValueKey(_WebSection.customerLedger));
      case _WebSection.paymentReport:
        return const PaymentReportWebScreen(key: ValueKey(_WebSection.paymentReport));
      case _WebSection.incomeExpenseReport:
        return const IncomeExpenseReportWebScreen(key: ValueKey(_WebSection.incomeExpenseReport));
    }
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps every open tab's widget mounted (just hidden) so
    // a partially filled-in entry screen stays exactly as it was when you
    // switch away to another tab and back, instead of being rebuilt fresh.
    final stackChildren = [_contentFor(_WebSection.home), for (final s in _openTabs) _contentFor(s)];
    final activeIndex = _active == _WebSection.home ? 0 : 1 + _openTabs.indexOf(_active);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: _sidebarCollapsed ? 76 : 260,
            child: _Sidebar(
              selected: _active,
              collapsed: _sidebarCollapsed,
              onSelect: _openSection,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  openTabs: _openTabs,
                  active: _active,
                  onSelectTab: _openSection,
                  onCloseTab: _closeTab,
                  sidebarCollapsed: _sidebarCollapsed,
                  onToggleSidebar: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  onLogout: _logout,
                ),
                Expanded(child: IndexedStack(index: activeIndex, children: stackChildren)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final _WebSection selected;
  final bool collapsed;
  final ValueChanged<_WebSection> onSelect;
  const _Sidebar({required this.selected, required this.collapsed, required this.onSelect});

  Widget _sectionLabel(String text) => collapsed
      ? const SizedBox(height: 16)
      : Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1),
          ),
        );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MysColors.navy900,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(collapsed ? 10 : 20, 24, collapsed ? 10 : 20, 28),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Image.asset('assets/icon/Company Logo 1.png', height: collapsed ? 48 : 110),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.home_outlined,
                    label: 'Home',
                    color: const Color(0xFFFDCB6E),
                    selected: selected == _WebSection.home,
                    onTap: () => onSelect(_WebSection.home),
                  ),
                  _sectionLabel('ENTRIES'),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.description_outlined,
                    label: 'Sales Order',
                    color: const Color(0xFF00B894),
                    selected: selected == _WebSection.salesOrder,
                    onTap: () => onSelect(_WebSection.salesOrder),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.local_shipping_outlined,
                    label: 'Trip Entry',
                    color: const Color(0xFF00CEC9),
                    selected: selected == _WebSection.tripEntry,
                    onTap: () => onSelect(_WebSection.tripEntry),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.local_shipping,
                    label: 'Delivery Entry',
                    color: const Color(0xFF55EFC4),
                    selected: selected == _WebSection.delivery,
                    onTap: () => onSelect(_WebSection.delivery),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.payments_outlined,
                    label: 'Payment Entry',
                    color: const Color(0xFF2ECC71),
                    selected: selected == _WebSection.payment,
                    onTap: () => onSelect(_WebSection.payment),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.cancel_outlined,
                    label: 'Cancel Entry',
                    color: const Color(0xFFE17055),
                    selected: selected == _WebSection.cancelEntry,
                    onTap: () => onSelect(_WebSection.cancelEntry),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.fact_check_outlined,
                    label: 'Sales Entry',
                    color: const Color(0xFF00B894),
                    selected: selected == _WebSection.salesEntry,
                    onTap: () => onSelect(_WebSection.salesEntry),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Income or Expenses',
                    color: const Color(0xFFFDCB6E),
                    selected: selected == _WebSection.incomeExpense,
                    onTap: () => onSelect(_WebSection.incomeExpense),
                  ),
                  _sectionLabel('REPORTS'),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.description_outlined,
                    label: 'Sales Order Report',
                    color: const Color(0xFF0984E3),
                    selected: selected == _WebSection.salesOrderReport,
                    onTap: () => onSelect(_WebSection.salesOrderReport),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.receipt_long_outlined,
                    label: 'Sales Report',
                    color: const Color(0xFF74B9FF),
                    selected: selected == _WebSection.salesReport,
                    onTap: () => onSelect(_WebSection.salesReport),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.local_shipping_outlined,
                    label: 'Trip Entry Report',
                    color: const Color(0xFF00CEC9),
                    selected: selected == _WebSection.tripEntryReport,
                    onTap: () => onSelect(_WebSection.tripEntryReport),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.local_shipping,
                    label: 'Delivery Report',
                    color: const Color(0xFF55EFC4),
                    selected: selected == _WebSection.deliveryReport,
                    onTap: () => onSelect(_WebSection.deliveryReport),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.account_balance_outlined,
                    label: 'Customer Ledger',
                    color: const Color(0xFF6C5CE7),
                    selected: selected == _WebSection.customerLedger,
                    onTap: () => onSelect(_WebSection.customerLedger),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.payments_outlined,
                    label: 'Payment Report',
                    color: const Color(0xFF2ECC71),
                    selected: selected == _WebSection.paymentReport,
                    onTap: () => onSelect(_WebSection.paymentReport),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Income and Expenses Report',
                    color: const Color(0xFFFDCB6E),
                    selected: selected == _WebSection.incomeExpenseReport,
                    onTap: () => onSelect(_WebSection.incomeExpenseReport),
                  ),
                  _sectionLabel('MASTERS'),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.inventory_2_outlined,
                    label: 'Product',
                    color: const Color(0xFF6C5CE7),
                    selected: selected == _WebSection.product,
                    onTap: () => onSelect(_WebSection.product),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.people_alt_outlined,
                    label: 'Customer',
                    color: const Color(0xFFA29BFE),
                    selected: selected == _WebSection.customer,
                    onTap: () => onSelect(_WebSection.customer),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.location_on_outlined,
                    label: 'Site',
                    color: const Color(0xFFFF7675),
                    selected: selected == _WebSection.site,
                    onTap: () => onSelect(_WebSection.site),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.link_outlined,
                    label: 'Customer Site Mapping',
                    color: const Color(0xFFFD79A8),
                    selected: selected == _WebSection.customerSiteMapping,
                    onTap: () => onSelect(_WebSection.customerSiteMapping),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.map_outlined,
                    label: 'Area',
                    color: const Color(0xFF00B894),
                    selected: selected == _WebSection.area,
                    onTap: () => onSelect(_WebSection.area),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle Mapping',
                    color: const Color(0xFFE17055),
                    selected: selected == _WebSection.vehicleMapping,
                    onTap: () => onSelect(_WebSection.vehicleMapping),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.badge_outlined,
                    label: 'Employee',
                    color: const Color(0xFF0984E3),
                    selected: selected == _WebSection.employee,
                    onTap: () => onSelect(_WebSection.employee),
                  ),
                  _NavItem(
                    collapsed: collapsed,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Head Master',
                    color: const Color(0xFFFDCB6E),
                    selected: selected == _WebSection.headMaster,
                    onTap: () => onSelect(_WebSection.headMaster),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        if (!collapsed) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );

    final button = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: row,
          ),
        ),
      ),
    );

    return collapsed ? Tooltip(message: label, child: button) : button;
  }
}

class _TopBar extends StatelessWidget {
  final List<_WebSection> openTabs;
  final _WebSection active;
  final ValueChanged<_WebSection> onSelectTab;
  final ValueChanged<_WebSection> onCloseTab;
  final bool sidebarCollapsed;
  final VoidCallback onToggleSidebar;
  final VoidCallback onLogout;
  const _TopBar({
    required this.openTabs,
    required this.active,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.sidebarCollapsed,
    required this.onToggleSidebar,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: MysColors.navy800,
            border: Border(bottom: BorderSide(color: Colors.black26)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(sidebarCollapsed ? Icons.menu : Icons.menu_open, color: Colors.white),
                tooltip: sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                onPressed: onToggleSidebar,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.business_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: CompanyProvider.instance,
                builder: (context, _) => Text(
                  CompanyProvider.instance.company?.companyName ?? 'MYS Sales',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.logout, color: Colors.white), tooltip: 'Logout', onPressed: onLogout),
            ],
          ),
        ),
        Container(
          height: 44,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF2FF),
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TabChip(
                  section: _WebSection.home,
                  active: active == _WebSection.home,
                  closable: false,
                  onTap: () => onSelectTab(_WebSection.home),
                  onClose: null,
                ),
                for (final s in openTabs)
                  _TabChip(
                    section: s,
                    active: active == s,
                    closable: true,
                    onTap: () => onSelectTab(s),
                    onClose: () => onCloseTab(s),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One tab in the top bar's tab strip — the active one rendered flush
/// white against the content area below it, inactive ones dimmed, with a
/// small close button on everything except the permanent Home tab.
class _TabChip extends StatelessWidget {
  final _WebSection section;
  final bool active;
  final bool closable;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _TabChip({
    required this.section,
    required this.active,
    required this.closable,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: EdgeInsets.fromLTRB(16, 0, closable ? 8 : 16, 0),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          border: Border(right: const BorderSide(color: Colors.black12), top: BorderSide(color: active ? MysColors.green500 : Colors.transparent, width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_sectionIcons[section] ?? Icons.circle_outlined, size: 16, color: MysColors.navy900),
            const SizedBox(width: 8),
            Text(
              _titleFor(section),
              style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: MysColors.navy900),
            ),
            if (closable) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: MysColors.navy900),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
