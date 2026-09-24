import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/cart_screen.dart';
import 'package:my_print_shop/frontend/screens/design_screen.dart';
import 'package:my_print_shop/frontend/screens/main_navigation_screen.dart';
import 'package:my_print_shop/frontend/screens/product_detail_screen.dart';

/// Shopfront initialisation smoke tests: the app shell boots, every tab
/// renders without overflow and the key landing sections are present, exactly
/// as a real customer would see them on first open.
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

Future<void> switchTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.text(label),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('shell + shopfront sections initialize at ${size.width.toInt()}px',
        (tester) async {
      await pumpShell(tester, size);

      // Four-tab shell.
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Home', skipOffstage: false), findsWidgets);
      expect(find.text('Designs', skipOffstage: false), findsWidgets);
      expect(find.text('Cart', skipOffstage: false), findsWidgets);
      expect(find.text('Profile', skipOffstage: false), findsWidgets);

      // Home shopfront: hero, search, offers strip, trust chips, categories.
      expect(find.text('CHOOSE YOUR PRODUCT'), findsOneWidget);
      expect(find.text('Search products, designs…'), findsOneWidget);
      expect(find.text('Offers & Promotions'), findsOneWidget);
      expect(find.text('Free delivery from ₹499'), findsWidgets);
      expect(find.text('Shop by Category'), findsOneWidget);
      expect(find.text('Create Your Own'), findsOneWidget);

      // Scroll Home fully to force every section to lay out (no overflow).
      await tester.dragUntilVisible(
        find.text('Customize Now'),
        find.byType(SingleChildScrollView).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'home should not overflow at ${size.width}px');
    });
  }

  testWidgets('Designs tab opens the global design library with filters',
      (tester) async {
    await pumpShell(tester, const Size(900, 1400));

    await switchTab(tester, 'Designs');
    expect(find.byType(DesignScreen), findsOneWidget);
    // The Design tab is the ALL-categories library, not a scoped category.
    expect(find.text('All Designs'), findsWidgets);
    expect(find.text('Design Inspiration'), findsWidgets);

    // The reusable-design library filters by theme (data-driven chips).
    expect(find.text('Browse by Theme'), findsOneWidget);
    expect(find.byKey(const ValueKey('design-theme-filters')), findsOneWidget);
    expect(find.text('Browse by Category'), findsOneWidget);
    expect(find.text('Browse by Type'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Cart tab offers a Start Shopping action and renders',
      (tester) async {
    await pumpShell(tester, const Size(390, 844));

    await switchTab(tester, 'Cart');
    expect(find.byType(CartScreen), findsOneWidget);
    expect(find.text('Your cart is empty!'), findsOneWidget);
    expect(find.text('Start Shopping'), findsOneWidget);

await switchTab(tester, 'Home');
      expect(find.text('Offers & Promotions'), findsOneWidget);
      expect(tester.takeException(), isNull);
  });

  testWidgets('featured carousel card opens the real product detail flow',
      (tester) async {
    await pumpShell(tester, const Size(800, 1400));

    await tester.tap(find.text('Customize').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
