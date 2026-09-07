import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:give_chain_app/core/widgets/app_logo.dart';

void main() {
  testWidgets('AppLogo renders without exceptions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppLogo())));

    expect(find.byType(AppLogo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
