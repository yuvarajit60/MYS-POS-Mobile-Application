import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/session.dart';
import 'create_trip_entry_screen.dart';
import 'login_screen.dart';
import 'main_shell_screen.dart';
import 'widgets/mys_app_bar_title.dart';

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
    final isDriver = Session.instance.isDriver;

    final tripEntryCard = _ActionCard(
      icon: Icons.local_shipping_outlined,
      label: 'Trip Entry',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateTripEntryScreen()),
      ),
    );

    // A driver's login is restricted to Trip Entry only — no Master/Entry/
    // Report sections at all.
    if (isDriver) {
      return Scaffold(
        appBar: AppBar(title: const MysAppBarTitle(), toolbarHeight: 68, actions: [_logoutButton(context)]),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroBanner(),
              const SizedBox(height: 14),
              _TileSection(title: 'Entry', tiles: [tripEntryCard]),
            ],
          ),
        ),
      );
    }

    // Non-drivers get the full bottom-nav shell (Home/Entries/Reports/More).
    return const MainShellScreen();
  }

  Widget _logoutButton(BuildContext context) => IconButton(
        icon: const Icon(Icons.logout),
        tooltip: 'Logout',
        onPressed: () => _logout(context),
      );
}

class _TileSection extends StatelessWidget {
  final String title;
  final List<Widget> tiles;

  const _TileSection({required this.title, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: MysColors.navy800),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.9,
          children: tiles,
        ),
      ],
    );
  }
}

/// Professional gradient banner — deliberately built from vector shapes/icons
/// rather than a stock photo, so the app stays fully self-contained.
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: MysColors.green500,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 28, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
