import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/session.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const AmselMobileApp());
}

class AmselMobileApp extends StatelessWidget {
  const AmselMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AMSEL Sales',
      debugShowCheckedModeBanner: false,
      theme: buildAmselTheme(),
      home: const _BootGate(),
    );
  }
}

/// Checks for a stored refresh token and silently exchanges it for a fresh
/// access token, so a returning user skips the login screen entirely and
/// lands straight on LandingScreen. Falls back to LoginScreen if there's no
/// stored token or the silent exchange fails (expired/revoked/etc).
class _BootGate extends StatefulWidget {
  const _BootGate();

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  bool _checking = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final success = await Session.instance.trySilentLogin();
    if (!mounted) return;
    setState(() {
      _authenticated = success;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _authenticated ? const LandingScreen() : const LoginScreen();
  }
}
