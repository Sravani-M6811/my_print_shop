import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/models/cart_item.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/cart_screen.dart';

/// Regression test: the placed-order card header (long generated orderId +
/// status Chip on one Row) used to overflow its 156px-wide container on narrow
/// screens. The orderId is the realistic generated form
/// (`ORD` + epoch-microseconds, e.g. 'ORD1726004973035012') which is far too
/// wide for a phone-width card with a status chip beside it.
///
/// A RenderFlex overflow reports a FlutterError, so `flutter_test` fails the
/// test automatically if the layout regresses at either size.
Future<void> pumpCart(WidgetTester tester, Size size,
    {required AppState appState}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: appState,
      child: const MaterialApp(home: CartScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> stateWithPlacedOrder() async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState();
    await appState.initialized;
    // Exercise the *generated* id form (microseconds epoch), matching what the
    // payment sheet actually produces, not a short hand-written constant.
    final orderId = 'ORD${DateTime.now().microsecondsSinceEpoch}';
    appState.addToCart(CartItem(
      id: 'overflow_test_1',
      title: 'Printed Cotton Tee',
      category: 'T-Shirts',
      customText: '',
      selectedSide: 'Front',
      fontFamily: 'Regular',
      price: 799,
      color: const Color(0xFF000000),
      quantity: 1,
    ));
    final ok = await appState.placeOrder(orderId: orderId);
    expect(ok, isTrue);
    expect(appState.orders, hasLength(1));
    expect(appState.orders.first.orderId, orderId);
    return appState;
  }

  for (final size in const [Size(320, 568), Size(390, 844), Size(1280, 800)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('placed-order card header renders without overflow at $label',
        (tester) async {
      final appState = await stateWithPlacedOrder();
      await pumpCart(tester, size, appState: appState);

      expect(find.byType(CartScreen), findsOneWidget);
      expect(find.text('Placed Orders'), findsOneWidget);
      expect(find.text(appState.orders.first.orderId), findsOneWidget);
      expect(find.text(appState.orders.first.status), findsOneWidget);
      // Any RenderFlex overflow would surface here as an exception.
      expect(tester.takeException(), isNull);
    });
  }
}
