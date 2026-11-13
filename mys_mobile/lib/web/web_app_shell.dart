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

class _WebAppShellState extends State<WebAppShell> {
  _WebSection _selected = _WebSection.home;

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

  String get _title {
    switch (_selected) {
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

  Widget get _content {
    switch (_selected) {
      case _WebSection.home:
        return const HomeWebScreen();
      case _WebSection.product:
        return const ProductMasterWebScreen();
      case _WebSection.customer:
        return const CustomerMasterWebScreen();
      case _WebSection.site:
        return const SiteMasterWebScreen();
      case _WebSection.customerSiteMapping:
        return const CustomerSiteMappingWebScreen();
      case _WebSection.area:
        return const AreaMasterWebScreen();
      case _WebSection.vehicleMapping:
        return const VehicleMappingWebScreen();
      case _WebSection.employee:
        return const EmployeeMasterWebScreen();
      case _WebSection.headMaster:
        return const HeadMasterWebScreen();
      case _WebSection.salesOrder:
        return const SalesOrderEntryWebScreen();
      case _WebSection.delivery:
        return const DeliveryEntryWebScreen();
      case _WebSection.tripEntry:
        return const TripEntryWebScreen();
      case _WebSection.payment:
        return const PaymentEntryWebScreen();
      case _WebSection.salesEntry:
        return const SalesEntryWebScreen();
      case _WebSection.incomeExpense:
        return const IncomeExpenseEntryWebScreen();
      case _WebSection.cancelEntry:
        return const CancelEntryWebScreen();
      case _WebSection.salesOrderReport:
        return const SalesOrderReportWebScreen();
      case _WebSection.salesReport:
        return const SalesReportWebScreen();
      case _WebSection.tripEntryReport:
        return const TripEntryReportWebScreen();
      case _WebSection.deliveryReport:
        return const DeliveryReportWebScreen();
      case _WebSection.customerLedger:
        return const LedgerReportWebScreen();
      case _WebSection.paymentReport:
        return const PaymentReportWebScreen();
      case _WebSection.incomeExpenseReport:
        return const IncomeExpenseReportWebScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(selected: _selected, onSelect: (s) => setState(() => _selected = s)),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: _title, onLogout: _logout),
                Expanded(child: _content),
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
  final ValueChanged<_WebSection> onSelect;
  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: MysColors.navy900,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Image.asset('assets/icon/mys_logo.png', height: 84),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    color: const Color(0xFFFDCB6E),
                    selected: selected == _WebSection.home,
                    onTap: () => onSelect(_WebSection.home),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text(
                      'ENTRIES',
                      style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.description_outlined,
                    label: 'Sales Order',
                    color: const Color(0xFF00B894),
                    selected: selected == _WebSection.salesOrder,
                    onTap: () => onSelect(_WebSection.salesOrder),
                  ),
                  _NavItem(
                    icon: Icons.local_shipping_outlined,
                    label: 'Trip Entry',
                    color: const Color(0xFF00CEC9),
                    selected: selected == _WebSection.tripEntry,
                    onTap: () => onSelect(_WebSection.tripEntry),
                  ),
                  _NavItem(
                    icon: Icons.local_shipping,
                    label: 'Delivery Entry',
                    color: const Color(0xFF55EFC4),
                    selected: selected == _WebSection.delivery,
                    onTap: () => onSelect(_WebSection.delivery),
                  ),
                  _NavItem(
                    icon: Icons.payments_outlined,
                    label: 'Payment Entry',
                    color: const Color(0xFF2ECC71),
                    selected: selected == _WebSection.payment,
                    onTap: () => onSelect(_WebSection.payment),
                  ),
                  _NavItem(
                    icon: Icons.cancel_outlined,
                    label: 'Cancel Entry',
                    color: const Color(0xFFE17055),
                    selected: selected == _WebSection.cancelEntry,
                    onTap: () => onSelect(_WebSection.cancelEntry),
                  ),
                  _NavItem(
                    icon: Icons.fact_check_outlined,
                    label: 'Sales Entry',
                    color: const Color(0xFF00B894),
                    selected: selected == _WebSection.salesEntry,
                    onTap: () => onSelect(_WebSection.salesEntry),
                  ),
                  _NavItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Income or Expenses',
                    color: const Color(0xFFFDCB6E),
                    selected: selected == _WebSection.incomeExpense,
                    onTap: () => onSelect(_WebSection.incomeExpense),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'REPORTS',
                      style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.description_outlined,
                    label: 'Sales Order Report',
                    color: const Color(0xFF0984E3),
                    selected: selected == _WebSection.salesOrderReport,
                    onTap: () => onSelect(_WebSection.salesOrderReport),
                  ),
                  _NavItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Sales Report',
                    color: const Color(0xFF74B9FF),
                    selected: selected == _WebSection.salesReport,
                    onTap: () => onSelect(_WebSection.salesReport),
                  ),
                  _NavItem(
                    icon: Icons.local_shipping_outlined,
                    label: 'Trip Entry Report',
                    color: const Color(0xFF00CEC9),
                    selected: selected == _WebSection.tripEntryReport,
                    onTap: () => onSelect(_WebSection.tripEntryReport),
                  ),
                  _NavItem(
                    icon: Icons.local_shipping,
                    label: 'Delivery Report',
                    color: const Color(0xFF55EFC4),
                    selected: selected == _WebSection.deliveryReport,
                    onTap: () => onSelect(_WebSection.deliveryReport),
                  ),
                  _NavItem(
                    icon: Icons.account_balance_outlined,
                    label: 'Customer Ledger',
                    color: const Color(0xFF6C5CE7),
                    selected: selected == _WebSection.customerLedger,
                    onTap: () => onSelect(_WebSection.customerLedger),
                  ),
                  _NavItem(
                    icon: Icons.payments_outlined,
                    label: 'Payment Report',
                    color: const Color(0xFF2ECC71),
                    selected: selected == _WebSection.paymentReport,
                    onTap: () => onSelect(_WebSection.paymentReport),
                  ),
                  _NavItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Income and Expenses Report',
                    color: const Color(0xFFFDCB6E),
                    selected: selected == _WebSection.incomeExpenseReport,
                    onTap: () => onSelect(_WebSection.incomeExpenseReport),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'MASTERS',
                      style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.inventory_2_outlined,
                    label: 'Product',
                    color: const Color(0xFF6C5CE7),
                    selected: selected == _WebSection.product,
                    onTap: () => onSelect(_WebSection.product),
                  ),
                  _NavItem(
                    icon: Icons.people_alt_outlined,
                    label: 'Customer',
                    color: const Color(0xFFA29BFE),
                    selected: selected == _WebSection.customer,
                    onTap: () => onSelect(_WebSection.customer),
                  ),
                  _NavItem(
                    icon: Icons.location_on_outlined,
                    label: 'Site',
                    color: const Color(0xFFFF7675),
                    selected: selected == _WebSection.site,
                    onTap: () => onSelect(_WebSection.site),
                  ),
                  _NavItem(
                    icon: Icons.link_outlined,
                    label: 'Customer Site Mapping',
                    color: const Color(0xFFFD79A8),
                    selected: selected == _WebSection.customerSiteMapping,
                    onTap: () => onSelect(_WebSection.customerSiteMapping),
                  ),
                  _NavItem(
                    icon: Icons.map_outlined,
                    label: 'Area',
                    color: const Color(0xFF00B894),
                    selected: selected == _WebSection.area,
                    onTap: () => onSelect(_WebSection.area),
                  ),
                  _NavItem(
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle Mapping',
                    color: const Color(0xFFE17055),
                    selected: selected == _WebSection.vehicleMapping,
                    onTap: () => onSelect(_WebSection.vehicleMapping),
                  ),
                  _NavItem(
                    icon: Icons.badge_outlined,
                    label: 'Employee',
                    color: const Color(0xFF0984E3),
                    selected: selected == _WebSection.employee,
                    onTap: () => onSelect(_WebSection.employee),
                  ),
                  _NavItem(
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
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
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
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onLogout;
  const _TopBar({required this.title, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: MysColors.navy800,
            border: Border(bottom: BorderSide(color: Colors.black26)),
          ),
          child: Row(
            children: [
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF2FF),
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.home_outlined, color: MysColors.navy900, size: 16),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MysColors.navy900)),
            ],
          ),
        ),
      ],
    );
  }
}
