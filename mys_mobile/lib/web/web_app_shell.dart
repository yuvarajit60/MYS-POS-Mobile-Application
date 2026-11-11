import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/company_provider.dart';
import '../core/session.dart';
import '../core/web_layout_mode.dart';
import '../screens/login_screen.dart';
import 'screens/head_master_web_screen.dart';

/// The web app's own shell — sidebar + top bar — deliberately not a reuse
/// of MainShellScreen's phone-style bottom nav (see main.dart's
/// _PhoneFrame comment). This is the pilot for the web's visual language:
/// a conventional admin-dashboard layout (sidebar nav grouped by section,
/// a content area, a top bar for page title + logout) inspired by the
/// desktop app's Masters/Transactions/Reports grouping but styled as a
/// modern web app, not a copy of either the desktop or mobile screens.
/// Only Head Master is wired up for now — more sections get added here as
/// each one gets its own web screen built.
class WebAppShell extends StatefulWidget {
  const WebAppShell({super.key});

  @override
  State<WebAppShell> createState() => _WebAppShellState();
}

enum _WebSection { headMaster }

class _WebAppShellState extends State<WebAppShell> {
  _WebSection _selected = _WebSection.headMaster;

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
      case _WebSection.headMaster:
        return 'Head Master';
    }
  }

  Widget get _content {
    switch (_selected) {
      case _WebSection.headMaster:
        return const HeadMasterWebScreen();
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
      width: 240,
      color: MysColors.navy900,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Row(
                children: [
                  Image.asset('assets/icon/mys_logo.png', height: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: CompanyProvider.instance,
                      builder: (context, _) => Text(
                        CompanyProvider.instance.company?.companyName ?? 'MYS Sales',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'MASTERS',
                style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1),
              ),
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Head Master',
              selected: selected == _WebSection.headMaster,
              onTap: () => onSelect(_WebSection.headMaster),
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
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: selected ? MysColors.green400 : Colors.white70, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
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
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: MysColors.navy900)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: onLogout),
        ],
      ),
    );
  }
}
