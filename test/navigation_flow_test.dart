import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/main_navigation_screen.dart';
import 'package:my_print_shop/frontend/screens/category_catalogue_screen.dart';
import 'package:my_print_shop/frontend/screens/cardboard_template_screen.dart';
import 'package:my_print_shop/frontend/screens/product_detail_screen.dart';
import 'package:my_print_shop/frontend/screens/design_customize_screen.dart';
import 'package:my_print_shop/frontend/screens/search_screen.dart';

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

  testWidgets('Cardboard: size -> template -> matter -> customize -> preview',
      (tester) async {
    await pumpApp(tester);

    // Home -> Cardboard category -> catalogue.
    await tester.tap(find.text('Cardboard').first);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCatalogueScreen), findsOneWidget);

    // Select a size product (first "View").
    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);

    // Cardboard uses the dedicated template flow (not the generic gallery).
    await tester.tap(find.widgetWithText(ElevatedButton, 'CHOOSE A DESIGN'));
    await tester.pumpAndSettle();
    expect(find.byType(CardboardTemplateScreen), findsOneWidget);

    // Select the first template card (scoped to the template screen because the
    // permanently-alive Design tab also renders 'Select' affordances).
    final inTemplate = find.descendant(
      of: find.byType(CardboardTemplateScreen),
      matching: find.text('Select'),
    );
    await tester.tap(inTemplate.first);
    await tester.pumpAndSettle();

    // Enter matter.
    final inTemplateField = find.descendant(
      of: find.byType(CardboardTemplateScreen),
      matching: find.byType(TextField),
    );
    await tester.enterText(inTemplateField.last, 'Happy Anniversary');
    await tester.pumpAndSettle();

    // Continue to customize; the selected template + matter are preserved.
    final inTemplate2 = find.descendant(
      of: find.byType(CardboardTemplateScreen),
      matching: find.text('Continue to Customize'),
    );
    await tester.ensureVisible(inTemplate2);
    await tester.pumpAndSettle();
    await tester.tap(inTemplate2);
    await tester.pumpAndSettle();
    expect(find.byType(DesignCustomizeScreen), findsOneWidget);
    expect(find.text('Your Selection'), findsOneWidget);
    expect(find.text('Happy Anniversary'), findsWidgets);

    // Continue to preview -> cart retains the full configuration.
    await tester.ensureVisible(find.textContaining('Continue to Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Continue to Preview'));
    await tester.pumpAndSettle();
    expect(find.text('Review Your Product'), findsOneWidget);

    await tester.tap(find.textContaining('Add to Cart'));
    await tester.pumpAndSettle();
  });

  testWidgets('Ready-Made: Product detail -> Add to Cart actually adds',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final rm = ProductCatalog.products.firstWhere((p) => p.isReadyMade);
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: MaterialApp(home: ProductDetailScreen(product: rm)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ADD TO CART'), findsOneWidget);
    await tester.ensureVisible(find.text('ADD TO CART'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD TO CART'));
    await tester.pumpAndSettle();

    // The item was really added to the cart.
    expect(find.textContaining('added to cart'), findsOneWidget);
    expect(appState.cartItems.length, 1);
    expect(appState.cartItems.first.title, rm.name);
  });

  testWidgets('View Cart pops the pushed routes and lands on the Cart tab',
      (tester) async {
    await pumpApp(tester);
    // Ready-made products now live in the Cart's "Trending Ready-Made" rail
    // (Home only curates categories + plain products).
    final rm = ProductCatalog.trendingReadyMade.isNotEmpty
        ? ProductCatalog.trendingReadyMade.first
        : ProductCatalog.allReadyMadeProducts.first;

    // Open the Cart tab where the Trending Ready-Made rail lives.
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Cart'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Trending Ready-Made'), findsWidgets);

    // Tap a trending ready-made card -> product detail.
    await tester.dragUntilVisible(
      find.text(rm.name).first,
      find.byType(SingleChildScrollView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(rm.name).first);
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);

    // Add to cart -> snackbar -> PROCEED TO CHECKOUT.
    await tester.ensureVisible(find.text('ADD TO CART'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD TO CART'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PROCEED TO CHECKOUT'));
    await tester.pumpAndSettle();

    // Back on the shell with the Cart tab active (pushed routes were popped).
    expect(find.byType(ProductDetailScreen), findsNothing);
    expect(find.text('Cart & Orders'), findsOneWidget);
    expect(find.text(rm.name), findsWidgets);
  });

  testWidgets('Search category result opens the category catalogue (not a list)',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Search products, designs…'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Mugs');
    await tester.pumpAndSettle();

    // Category chip -> CategoryCatalogueScreen (consistent with Home).
    await tester.tap(find.widgetWithText(ActionChip, 'Mugs'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCatalogueScreen), findsOneWidget);
  });

  testWidgets('Home Customize Now offers a category picker (no hardcoded Sarees)',
      (tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Customize Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customize Now'));
    await tester.pumpAndSettle();

    // The bottom sheet shows the eight category choices.
    expect(find.text('Choose a category to customize'), findsOneWidget);
    expect(find.text('Mugs'), findsWidgets);

    // Selecting a category opens its catalogue.
    await tester.tap(find.widgetWithText(ActionChip, 'Mugs').first);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCatalogueScreen), findsOneWidget);
  });
}
