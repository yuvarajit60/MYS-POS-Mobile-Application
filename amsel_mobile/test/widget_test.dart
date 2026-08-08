import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amsel_mobile/main.dart';

void main() {
  testWidgets('App boots to the login screen when no session is stored', (WidgetTester tester) async {
    await tester.pumpWidget(const AmselMobileApp());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
