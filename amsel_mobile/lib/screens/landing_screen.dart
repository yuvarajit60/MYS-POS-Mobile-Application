import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/session.dart';
import 'create_sales_order_screen.dart';
import 'login_screen.dart';
import 'manage_customers_screen.dart';
import 'manage_products_screen.dart';
import 'reports_screen.dart';
import 'widgets/amsel_app_bar_title.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await Session.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AmselAppBarTitle(),
        toolbarHeight: 68,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroBanner(),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.05,
              children: [
                _ActionCard(
                  icon: Icons.add_shopping_cart,
                  label: 'Create Sales Order',
                  highlighted: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateSalesOrderScreen()),
                  ),
                ),
                _ActionCard(
                  icon: Icons.assessment_outlined,
                  label: 'Reports',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  ),
                ),
                _ActionCard(
                  icon: Icons.people_alt_outlined,
                  label: 'Customers',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ManageCustomersScreen()),
                  ),
                ),
                _ActionCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Products',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ManageProductsScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Professional gradient banner — deliberately built from vector shapes/icons
/// rather than a stock photo, so the app stays fully self-contained.
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AmselColors.charcoal, Color(0xFF3A3A3C)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: AmselColors.gold, shape: BoxShape.circle),
            child: const Icon(Icons.storefront, color: AmselColors.charcoal, size: 32),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 2),
                Text(
                  'Home',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up, color: AmselColors.gold, size: 28),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlighted ? AmselColors.gold : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: AmselColors.charcoal),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AmselColors.charcoal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
