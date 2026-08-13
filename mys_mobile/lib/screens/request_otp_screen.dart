import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'otp_screen.dart';

/// First step of the "first time user" flow: ask for the mobile number
/// registered against the account (not the internal system username), send
/// an OTP to it, then hand off to OtpScreen for code entry.
class RequestOtpScreen extends StatefulWidget {
  const RequestOtpScreen({super.key});

  @override
  State<RequestOtpScreen> createState() => _RequestOtpScreenState();
}

class _RequestOtpScreenState extends State<RequestOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final mobileNo = _mobileController.text.trim();
    try {
      await _authService.requestOtp(mobileNo);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtpScreen(mobileNo: mobileNo)));
    } on AuthException catch (e) {
      if (e.statusCode == 502) {
        // The code was generated server-side even though the SMS itself
        // couldn't be delivered (e.g. no SMS provider configured yet) — still
        // let the user proceed to enter a code obtained another way.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${e.message} A code was still generated — ask your administrator for it.')),
        );
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtpScreen(mobileNo: mobileNo)));
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify by OTP')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Enter your registered mobile number to receive a one-time code.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading ? const CircularProgressIndicator() : const Text('Send OTP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
