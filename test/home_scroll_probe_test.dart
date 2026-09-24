import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_print_shop/frontend/screens/home_screen.dart';

Future<void> pumpHome(WidgetTester tester, {Size size = const Size(360, 640)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: HomeScreen()),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home whole page scrolls as one unit at small viewport', (tester) async {
    await pumpHome(tester);
    expect(tester.takeException(), isNull,
        reason: 'Home should not overflow at small viewport');

    final scrollable = find.byType(Scrollable).first;
    expect(tester.widget<Scrollable>(scrollable).axisDirection, AxisDirection.down);

    await tester.fling(find.byType(SingleChildScrollView), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Home page scroll should not throw');
  });
}
