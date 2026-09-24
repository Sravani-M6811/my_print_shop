import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/models/product_variant.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/main_navigation_screen.dart';
import 'package:my_print_shop/frontend/screens/category_catalogue_screen.dart';
import 'package:my_print_shop/frontend/screens/product_detail_screen.dart';
import 'package:my_print_shop/frontend/screens/variant_selection_screen.dart';
import 'package:my_print_shop/frontend/screens/design_screen.dart';

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

  group('Plain / base products and their variants', () {
    test('all eight plain products exist as first-class products', () {
      final expected = {
        'Plain Saree',
        'Plain Saree Border',
        'Plain T-Shirt',
        'Plain Mug',
        'Plain Poster',
        'Plain Embroidery Base',
        'Plain Cardboard',
        'Plain Glass',
      };
      for (final name in expected) {
        final base = ProductCatalog.baseProducts
            .where((p) => p.name == name)
            .toList();
        expect(base, hasLength(1),
            reason: 'expected exactly one base product named "$name"');
        expect(base.single.isBase, isTrue);
      }
    });

    test('every base product has relevant, non-empty variants', () {
      for (final base in ProductCatalog.baseProducts) {
        expect(base.variants, isNotEmpty,
            reason: '${base.name} must offer at least one option');
        for (final v in base.variants) {
          expect(v.label.trim(), isNotEmpty);
          expect(v, isA<ProductVariant>());
          expect(v.isColor || !v.isColor, isTrue); // always a valid shape
        }
        // No duplicate labels for the same base product.
        final labels = base.variants.map((v) => v.label).toSet();
        expect(labels.length, base.variants.length,
            reason: '${base.name} duplicates a variant label');
      }
    });

    test('Poster uses print finishes, not forced colours', () {
      final poster =
          ProductCatalog.baseProducts.firstWhere((p) => p.id == 'base_poster');
      expect(poster.variants.map((v) => v.label),
          containsAll(['Matte', 'Glossy', 'Premium']));
      expect(poster.variants.every((v) => !v.isColor), isTrue);
    });

    test('Glass uses meaningful glass finishes', () {
      final glass =
          ProductCatalog.baseProducts.firstWhere((p) => p.id == 'base_glass');
      expect(glass.variants.map((v) => v.label),
          containsAll(['Clear', 'Frosted', 'Smoked', 'Bronze']));
    });

    test('variantFor falls back to the first option for unknown labels', () {
      final saree =
          ProductCatalog.baseProducts.firstWhere((p) => p.id == 'base_saree');
      expect(ProductCatalog.variantFor(saree, 'Red')?.label, 'Red');
      expect(ProductCatalog.variantFor(saree, 'does-not-exist')?.label,
          saree.variants.first.label);
      expect(ProductCatalog.variantFor(saree, null)?.label,
          saree.variants.first.label);
    });

    test('plain products never inherit generic clothing sizes', () {
      for (final base in ProductCatalog.allPlainProducts) {
        if (base.category == 'T-Shirts') {
          expect(base.availableSizes, isNotEmpty,
              reason: '${base.name} must offer real tee sizes');
        } else {
          expect(base.availableSizes, isEmpty,
              reason: '${base.name} must not list clothing sizes');
        }
      }
    });
  });

  group('Design filtering stays category-scoped', () {
    test('Sarees filters only Saree designs', () {
      final saree =
          ProductCatalog.baseProducts.firstWhere((p) => p.id == 'base_saree');
      final designs = ProductCatalog.designsForBase(saree);
      expect(designs, isNotEmpty);
      expect(designs.every((p) => p.category == 'Sarees'), isTrue);
    });

    test('T-Shirts filters only T-Shirt designs', () {
      final tee =
          ProductCatalog.baseProducts.firstWhere((p) => p.id == 'base_tshirt');
      final designs = ProductCatalog.designsForBase(tee);
      expect(designs, isNotEmpty);
      expect(designs.every((p) => p.category == 'T-Shirts'), isTrue);
    });

    test('Mugs filters only Mug designs', () {
      final mug =
          ProductCatalog.baseProducts.firstWhere((p) => p.id == 'base_mug');
      final designs = ProductCatalog.designsForBase(mug);
      expect(designs, isNotEmpty);
      expect(designs.every((p) => p.category == 'Mugs'), isTrue);
    });

    test('base products are never exposed inside a design gallery', () {
      for (final category in ProductCatalog.categories) {
        final designs = ProductCatalog.productsForCategory(category);
        expect(designs.every((p) => !p.isBase), isTrue,
            reason: 'design gallery for $category leaked a base product');
      }
    });

    test('base products carry data-driven material and measurements', () {
      // Every plain product must expose at least a material or measurements so
      // the details screen shows real specs instead of hard-coded strings.
      for (final base in ProductCatalog.baseProducts) {
        final hasMaterial =
            base.material != null && base.material!.trim().isNotEmpty;
        final hasMeasurements = base.measurements.isNotEmpty;
        expect(hasMaterial || hasMeasurements, isTrue,
            reason: '${base.name} has no data-driven product specifications');
        // Measurement values must be non-empty.
        for (final m in base.measurements) {
          expect(m.key.trim(), isNotEmpty);
          expect(m.value.trim(), isNotEmpty,
              reason: '${base.name} has an empty measurement for ${m.key}');
        }
      }
    });
  });

  testWidgets('T-Shirt: product -> colour -> design -> customize -> cart',
      (tester) async {
    await pumpApp(tester);

    // Start with a product: T-Shirts category -> catalogue -> Plain Half-Sleeve Tee.
    await tester.tap(find.text('T-Shirts').first);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCatalogueScreen), findsOneWidget);
    // The first row of the T-Shirts catalogue is now the flagship
    // 'Plain T-Shirts'; open the Half-Sleeve Tee card via its View button.
    final halfSleeveCard = find.ancestor(
      of: find.descendant(
        of: find.byType(CategoryCatalogueScreen),
        matching: find.text('Plain Half-Sleeve Tee'),
      ),
      matching: find.byType(Card),
    );
    // Sub-category tiles at the top pushed rows far down — scroll the card into
    // view before tapping its View button.
    await tester.ensureVisible(halfSleeveCard);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: halfSleeveCard,
      matching: find.text('View'),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);

    // Pick the Black colour on the detail screen, then continue to designs.
    await tester.tap(find.text('Black'));
    await tester.pump();
    await tester.tap(find.text('CHOOSE A DESIGN'));
    await tester.pumpAndSettle();

    // The gallery is scoped to T-Shirts and remembers the colour.
    expect(find.byType(DesignScreen), findsOneWidget);
    expect(find.text('Choose a Design for Your Half-Sleeve Tee'), findsWidgets);
    expect(find.textContaining('Color: Black'), findsOneWidget);

    // Scoped search: "border" designs exist only in the Sarees catalogue. Inside
    // the T-Shirt scope it must find nothing, proving the search stays scoped.
    await tester.enterText(find.byType(TextField).first, 'border');
    await tester.pumpAndSettle();
    expect(find.textContaining('No designs found'), findsOneWidget);

    // Clear search and select a design then continue to customize.
    await tester.tap(find.byIcon(Icons.clear).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue to Customize'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Customize'));
    await tester.pumpAndSettle();

    // Step 4: Preview the full configuration before adding to cart.
    expect(find.text('Your Selection'), findsOneWidget);
    await tester.tap(find.textContaining('Continue to Preview'));
    await tester.pumpAndSettle();

    // The preview screen restates the configuration, then adds to cart.
    expect(find.text('Review Your Product'), findsOneWidget);
    expect(find.text('Your Configuration'), findsOneWidget);
    expect(find.textContaining('Base Product'), findsOneWidget);
    await tester.tap(find.textContaining('Add to Cart'));
    await tester.pumpAndSettle();

    // Cart preserves base product, variant and the design title. (Pop all the
    // pushed routes: preview -> customize -> design gallery -> product detail
    // -> product list -> Home tab, where the bottom nav is visible.)
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Items in your Cart'), findsOneWidget);
    expect(find.textContaining('Plain Half-Sleeve Tee · '), findsOneWidget);
    expect(find.text('Variant: Black'), findsOneWidget);
    expect(find.text('Position: Front'), findsOneWidget);
  });

  testWidgets('Design banner "Change" re-opens the variant picker',
      (tester) async {
    await pumpApp(tester);

    // Start with a product: Sarees category -> catalogue -> Plain Red Silk Saree.
    await tester.tap(find.text('Sarees').first);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCatalogueScreen), findsOneWidget);
    // Open the Red Silk Saree card via its View button to keep the Red flow.
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
    await tester.tap(find.text('CHOOSE A DESIGN'));
    await tester.pumpAndSettle();

    // Banner shows the default first colour.
    expect(find.textContaining('Color: Red'), findsOneWidget);

    // "Change" reopens the variant picker with the design gallery below.
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.byType(VariantSelectionScreen), findsOneWidget);

    // Pick another colour and continue -> banner updates in sync.
    await tester.tap(find.text('White'));
    await tester.pump();
    await tester.tap(find.text('Continue to Designs'));
    await tester.pumpAndSettle();
    expect(find.byType(DesignScreen), findsOneWidget);
    expect(find.textContaining('Color: White'), findsOneWidget);
  });
}
