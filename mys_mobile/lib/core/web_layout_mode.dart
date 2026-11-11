import 'package:flutter/foundation.dart';

/// Set by WebAppShell while it's mounted, so main.dart's phone-width frame
/// (added for the still-phone-styled Login/Landing screens on a wide
/// browser) knows to get out of the way and let the web shell use the
/// full viewport instead of squeezing it into a phone-sized box.
class WebLayoutMode {
  WebLayoutMode._();
  static final ValueNotifier<bool> fullWidth = ValueNotifier<bool>(false);
}
