import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/session.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MysMobileApp());
}

class MysMobileApp extends StatelessWidget {
  const MysMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MYS Sales',
      debugShowCheckedModeBanner: false,
      theme: buildMysTheme(),
      home: const _BootGate(),
      builder: (context, child) => _PhoneFrame(child: child),
    );
  }
}

/// This UI was designed phone-first (fixed bottom nav, grids sized for a
/// narrow screen). On web, a wide browser window stretches that same
/// layout edge-to-edge, spreading everything out oddly instead of just
/// showing more content. Rather than reflow every screen for desktop, this
/// keeps the app at a phone-like width and centers it on wider viewports —
/// native Android/iOS builds and narrow browser windows are unaffected.
class _PhoneFrame extends StatelessWidget {
  final Widget? child;
  const _PhoneFrame({required this.child});

  static const _maxWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final child = this.child;
    if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= _maxWidth) return child;
        return ColoredBox(
          color: MysColors.navy900,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Material(elevation: 12, child: child),
            ),
          ),
        );
      },
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
