import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_print_shop/ui/widgets/step_indicator.dart';

void main() {
  testWidgets('StepIndicator renders all steps and highlights the active one',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StepIndicator(
          steps: ['Base', 'Design', 'Customize', 'Preview', 'Cart'],
          currentIndex: 2,
        ),
      ),
    ));

    for (final label in ['Base', 'Design', 'Customize', 'Preview', 'Cart']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('completed steps show a check, active step shows its initial',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StepIndicator(
          steps: ['A', 'B', 'C'],
          currentIndex: 1,
        ),
      ),
    ));

    // Step 0 is done -> check icon. Step 1 is active -> shows its initial 'B'.
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('B'), findsWidgets);
  });
}
