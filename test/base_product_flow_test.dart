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

  testWidgets('Home base product narrows the Design gallery to its category',
      (tester) async {
    await pumpApp(tester);

    // The Home screen offers a product-first "Shop by Category" entry point.
    expect(find.text('Shop by Category'), findsOneWidget);

    // Start with a product: Sarees category -> sectioned catalogue -> detail.
    await tester.tap(find.text('Sarees').first);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCatalogueScreen), findsOneWidget);
    // The flagship silk saree is the first card in the first row; open its
    // card via its View button so the Red Silk flow below stays intact.
    final silkRedCard = find.ancestor(
      of: find.descendant(
        of: find.byType(CategoryCatalogueScreen),
        matching: find.text('Plain Red Silk Saree'),
      ),
      matching: find.byType(Card),
    );
    await tester.tap(find.descendant(
      of: silkRedCard,
      matching: find.text('View'),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);

    // Pick the Red colour on the detail screen, then continue to the design
    // gallery for that product.
    await tester.tap(find.text('Red'));
    await tester.pump();
    await tester.tap(find.text('CHOOSE A DESIGN'));
    await tester.pumpAndSettle();

    expect(find.byType(DesignScreen), findsOneWidget);
    // Header reflects the chosen base product and the banner shows the colour.
    expect(find.text('Choose a Design for Your Red Silk Saree'), findsWidgets);
    expect(find.textContaining('Color: Red'), findsOneWidget);

    // The narrowed gallery scopes search to that category: searching for a
    // design that exists only in another category (mugs) finds nothing here.
    await tester.enterText(find.byType(TextField).first, 'mug');
    await tester.pumpAndSettle();
    expect(find.textContaining('No designs found'), findsOneWidget);

    // Clear search and pick a design -> customize -> preview -> cart keeps all.
    await tester.tap(find.byIcon(Icons.clear).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue to Customize'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Customize'));
    await tester.pumpAndSettle();
    expect(find.byType(DesignCustomizeScreen), findsOneWidget);

    // The customize step keeps the base product locked in and shows the
    // configuration summary (base product + colour + design).
    expect(find.text('Your Selection'), findsOneWidget);
    expect(find.text('Plain Red Silk Saree'), findsWidgets);

    // Step 4: Preview before the cart (replaces the old direct add-to-cart).
    await tester.tap(find.textContaining('Continue to Preview'));
    await tester.pumpAndSettle();

    // The preview screen re-states the full configuration and lets the
    // customer add it to the cart.
    expect(find.text('Review Your Product'), findsOneWidget);
    expect(find.text('Your Configuration'), findsOneWidget);
    expect(find.textContaining('Base Product'), findsOneWidget);
    await tester.tap(find.textContaining('Add to Cart'));
    await tester.pumpAndSettle();

    // Back out of the preview, through customize and the design gallery,
    // product list and detail, to the Home tab, then to Cart; the item title
    // retains the base + design and the variant selection is preserved.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Items in your Cart'), findsOneWidget);
    expect(find.textContaining('Plain Red Silk Saree · '), findsOneWidget);
    expect(find.textContaining('Red'), findsWidgets);
  });

  testWidgets('Design tab opened directly shows the full catalogue',
      (tester) async {
    await pumpApp(tester);

    // Open the Design tab directly (bottom nav) -> global all-categories
    // library (never a hardcoded category).
    await tester.tap(find.text('Designs'));
    await tester.pumpAndSettle();
    expect(find.byType(DesignScreen), findsOneWidget);
    expect(find.text('All Designs'), findsWidgets);
  });
}
