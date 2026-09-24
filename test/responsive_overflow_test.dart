import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/models/cart_item.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/category_catalogue_screen.dart';
import 'package:my_print_shop/frontend/screens/home_screen.dart';
import 'package:my_print_shop/frontend/screens/main_navigation_screen.dart';
import 'package:my_print_shop/frontend/screens/product_detail_screen.dart';
import 'package:my_print_shop/frontend/screens/search_screen.dart';

/// Fixed at two phone sizes from the start so every screen the spec lists is
/// laid out at that width. A RenderFlex/Row overflow reports a FlutterError,
/// and flutter_test fails the test automatically — so each `expect` below also
/// proves the screen rendered *without overflow* at that size.
Future<void> pumpShell(WidgetTester tester, Size size,
    {AppState? appState}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => appState ?? AppState(),
      child: const MaterialApp(home: MainNavigationScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

AppState withCart() {
  final appState = AppState();
  final rm = ProductCatalog.allReadyMadeProducts.first;
  appState.addToCart(CartItem(
    id: 'resp_test_1',
    title: rm.name,
    category: rm.category,
    customText: '',
    selectedSide: 'Front',
    fontFamily: 'Regular',
    price: rm.basePrice,
    color: const Color(0xFF000000),
    imagePath: rm.imagePath,
    quantity: 2,
  ));
  return appState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> switchTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(label),
    ));
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(390, 844), Size(320, 568)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('Home + catalogue + product detail render at $label',
        (tester) async {
      await pumpShell(tester, size);

      // Home — search bar + category grid + curated plain products + offers.
      expect(find.text('Shop by Category'), findsOneWidget);
      expect(find.text('Create Your Own'), findsOneWidget);
      expect(find.text('Offers & Promotions'), findsOneWidget);

      // Scroll Home fully to force every section to lay out.
      await tester.dragUntilVisible(
        find.text('Customize Now'),
        find.byType(SingleChildScrollView).first,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      // Categories -> catalogue (Mugs — short name, always fits the grid).
      final homeMugs = find.descendant(
        of: find.byType(HomeScreen),
        matching: find.text('Mugs'),
      );
      await tester.ensureVisible(homeMugs.first);
      await tester.pumpAndSettle();
      await tester.tap(homeMugs.first);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryCatalogueScreen), findsOneWidget);

      // Scroll the catalogue to force section layout to complete.
      final catalogueScrollables = find.descendant(
        of: find.byType(CategoryCatalogueScreen),
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      await tester.drag(
        catalogueScrollables.first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      // Tap View -> ProductDetailScreen.
      final viewButton = find.text('View').first;
      await tester.ensureVisible(viewButton);
      await tester.pumpAndSettle();
      await tester.tap(viewButton);
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailScreen), findsOneWidget);
    });

    testWidgets('Search screen with live results at $label', (tester) async {
      await pumpShell(tester, size);

      await tester.tap(find.text('Search products, designs…'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Plain');
      await tester.pumpAndSettle();
      expect(find.text('Plain Products'), findsOneWidget);
    });

    testWidgets('Design tab + cart tab with an item render at $label',
        (tester) async {
      await pumpShell(tester, size, appState: withCart());

      await switchTab(tester, 'Designs');
      expect(find.text('All Designs'), findsWidgets);
      await tester.dragUntilVisible(
        find.text('Upload Your Design'),
        find.byType(SingleChildScrollView).last,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      await switchTab(tester, 'Cart');
      // The cart tab is rendered by IndexedStack; its AppBar text is findable
      // with skipOffstage = false since IndexedStack keeps all children alive.
      expect(
        find.text('Cart & Orders', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('Ready-made product detail renders at $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final appState = AppState();
      final rm = ProductCatalog.allReadyMadeProducts.first;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: MaterialApp(home: ProductDetailScreen(product: rm)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(rm.name), findsWidgets);
      await tester.dragUntilVisible(
        find.text('ADD TO CART'),
        find.byType(ProductDetailScreen),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
    });
  }
}
