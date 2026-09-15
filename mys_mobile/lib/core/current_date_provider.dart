import 'package:flutter/foundation.dart';
import '../models/change_date.dart';
import '../services/change_date_service.dart';

/// Fetches the legacy desktop app's "business date" (dbo.CHANGE_DATE) and
/// caches it in memory so Entry/Report date controls default to it instead
/// of the device's real clock — the business date can lag behind the wall
/// clock until someone runs a "day close" on the desktop app.
/// [reset] must be called on every login/logout so a cached date from one
/// tenant's session never leaks into another's — see Session.
class CurrentDateProvider extends ChangeNotifier {
  CurrentDateProvider._internal();
  static final CurrentDateProvider instance = CurrentDateProvider._internal();

  ChangeDate? changeDate;
  bool _fetching = false;

  DateTime get currentDate => changeDate?.currentDate ?? DateTime.now();

  Future<void> ensureLoaded() async {
    if (changeDate != null || _fetching) return;
    _fetching = true;
    try {
      changeDate = await ChangeDateService().get();
      if (changeDate != null) notifyListeners();
    } finally {
      _fetching = false;
    }
  }

  void reset() {
    changeDate = null;
    notifyListeners();
  }
}
