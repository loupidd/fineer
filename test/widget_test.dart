import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fineer/main.dart';

void main() {
  testWidgets('Fineer app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FineerApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
