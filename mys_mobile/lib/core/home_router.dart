import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../screens/landing_screen.dart';
import '../web/web_app_shell.dart';

/// Single decision point for "where does an authenticated user land" — the
/// web app's own shell (lib/web/) vs the mobile app's bottom-nav
/// LandingScreen. Both _BootGate (silent login on app boot) and
/// LoginScreen (after a fresh login) route through this instead of each
/// hardcoding one or the other.
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return kIsWeb ? const WebAppShell() : const LandingScreen();
  }
}
