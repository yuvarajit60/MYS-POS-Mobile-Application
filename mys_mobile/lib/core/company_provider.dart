import 'package:flutter/foundation.dart';
import '../models/company.dart';
import '../services/company_service.dart';

/// Fetches the configured company name and caches it in memory for the app
/// bar title. `/api/company` now requires auth (each tenant has its own
/// company record, so an anonymous pre-login request has no way to know
/// which one to return) — the login screen's app bar just shows the
/// generic "MYS Sales" fallback until the user is actually signed in.
/// [reset] must be called on every login/logout so a cached company from
/// one tenant's session never leaks into another's — see Session.
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

  void reset() {
    company = null;
    notifyListeners();
  }
}
