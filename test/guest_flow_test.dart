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

  testWidgets('Guest: browse -> product list -> detail -> add to cart',
      (tester) async {
    await pumpApp(tester);

    // Home shows the product-first "Shop by Category" entry point.
    expect(find.text('Shop by Category'), findsOneWidget);

    // Tap a category tile -> sectioned catalogue.
    await tester.tap(find.text('Sarees').first);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCatalogueScreen), findsOneWidget);

    // Tap a product card -> ProductDetailScreen.
    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    // Base products show "CHOOSE A DESIGN" instead of "Add to Cart"
    expect(
      find.widgetWithText(ElevatedButton, 'CHOOSE A DESIGN'),
      findsOneWidget,
    );

    // Continue to design selection.
    await tester.tap(find.widgetWithText(ElevatedButton, 'CHOOSE A DESIGN'));
    await tester.pumpAndSettle();

    // Select the first design card, then continue to the customization studio.
    await tester.tap(find.text('Select').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue to Customize'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Customize'));
    await tester.pumpAndSettle();
    expect(find.byType(DesignCustomizeScreen), findsOneWidget);

    // Continue to the preview step, then add the custom design to cart.
    await tester.tap(find.textContaining('Continue to Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Add to Cart'));
    await tester.pumpAndSettle();

    // Back to home tab: preview -> customize -> design -> product detail
    // -> product list -> main navigation shell, then switch to Cart tab.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Items in your Cart'), findsOneWidget);
  });

  testWidgets('Guest: Design gallery -> select design -> customize -> cart',
      (tester) async {
    await pumpApp(tester);

    // Go to Design tab.
    await tester.tap(find.text('Designs'));
    await tester.pumpAndSettle();
    expect(find.byType(DesignScreen), findsOneWidget);

    // The gallery should NOT auto-open the upload picker.
    expect(find.text('Upload Your Design'), findsWidgets);

    // Select the first design -> customization studio.
    await tester.tap(find.text('Customize').first);
    await tester.pumpAndSettle();
    expect(find.byType(DesignCustomizeScreen), findsOneWidget);

    // Continue to the preview step, then add the custom design to cart.
    await tester.tap(find.textContaining('Continue to Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Add to Cart'));
    await tester.pumpAndSettle();

    // Back to the gallery (back twice: preview -> customize -> gallery tab),
    // then to Cart.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Items in your Cart'), findsOneWidget);

    // Increase quantity.
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('Guest: empty cart state shows placeholder', (tester) async {
    await pumpApp(tester);

    // Go to Cart tab directly with no items.
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty!'), findsOneWidget);
  });
}
