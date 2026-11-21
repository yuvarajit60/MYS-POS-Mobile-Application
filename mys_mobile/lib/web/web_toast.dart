import 'package:flutter/material.dart';

/// Web admin screens anchor their save/validation toasts to the bottom-right
/// of the window — Material's default SnackBar spans/hugs the left edge,
/// which reads fine on a phone-width mobile screen but gets lost on a wide
/// desktop layout. Width is fixed; the left margin is computed from the
/// window's current width so the toast stays pinned to the right instead of
/// centering, and degrades to near-full-width if the window is narrow.
void showWebMessage(BuildContext context, String message) {
  const toastWidth = 380.0;
  const edgeMargin = 24.0;
  final windowWidth = MediaQuery.of(context).size.width;
  final leftMargin = (windowWidth - toastWidth - edgeMargin).clamp(16.0, double.infinity);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(left: leftMargin, right: edgeMargin, bottom: edgeMargin),
    ),
  );
}
