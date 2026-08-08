import 'package:flutter/foundation.dart';
import '../models/company.dart';
import '../services/company_service.dart';

/// Fetches the configured company name once (it's shown pre-login too, e.g.
/// on the sign-in screen) and caches it in memory for the app bar title.
class CompanyProvider extends ChangeNotifier {
  CompanyProvider._internal();
  static final CompanyProvider instance = CompanyProvider._internal();

  Company? company;
  bool _fetching = false;

  Future<void> ensureLoaded() async {
    if (company != null || _fetching) return;
    _fetching = true;
    try {
      company = await CompanyService().get();
      if (company != null) notifyListeners();
    } finally {
      _fetching = false;
    }
  }
}
