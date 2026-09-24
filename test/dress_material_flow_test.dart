import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/main_navigation_screen.dart';
import 'package:my_print_shop/frontend/screens/category_catalogue_screen.dart';
import 'package:my_print_shop/frontend/screens/product_detail_screen.dart';
import 'package:my_print_shop/frontend/screens/design_screen.dart';
import 'package:my_print_shop/frontend/screens/design_customize_screen.dart';

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(home: MainNavigationScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Dress Materials: with/without stitching flows customize -> preview -> cart',
      (tester) async {
    await pumpApp(tester);

    // Home -> Dress Materials category -> sectioned catalogue -> product detail.
    await tester.tap(find.text('Dress Materials').first);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCatalogueScreen), findsOneWidget);
    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'CHOOSE A DESIGN'));
    await tester.pumpAndSettle();
    expect(find.byType(DesignScreen), findsOneWidget);

    // Pick the first compatible design and continue to the customize studio.
    await tester.tap(find.text('Select').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue to Customize'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Customize'));
    await tester.pumpAndSettle();
    expect(find.byType(DesignCustomizeScreen), findsOneWidget);

    // The stitching option is offered for Dress Materials, defaulting to
    // "With Stitching", and the user can switch to "Without Stitching".
    await tester.ensureVisible(find.text('Without Stitching'));
    await tester.pumpAndSettle();
    expect(find.text('Stitching:'), findsOneWidget);
    await tester.tap(find.text('Without Stitching'));
    await tester.pump();

    // Continue to preview: the stitching choice is restated.
    await tester.ensureVisible(find.textContaining('Continue to Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Continue to Preview'));
    await tester.pumpAndSettle();
    expect(find.text('Review Your Product'), findsOneWidget);
    expect(find.text('Without Stitching'), findsOneWidget);

    // Add to cart, then pop back and open the cart to confirm it persists.
    await tester.tap(find.textContaining('Add to Cart'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Items in your Cart'), findsOneWidget);
    expect(find.text('Stitching: Without Stitching'), findsOneWidget);
  });
}
