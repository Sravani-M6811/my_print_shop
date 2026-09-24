import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/screens/category_catalogue_screen.dart';
import 'package:my_print_shop/frontend/screens/product_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sarees subcategories keep the required order and borders are designs',
      () {
    final sections = ProductCatalog.subcategoriesForCategory('Sarees');
    expect(
      sections,
      [
        'Silk Plain Sarees',
        'Cotton Sarees',
        'Crepe Silk Sarees',
        'Pattu Sarees',
        'Georgette Plain Sarees',
        'Trending Sarees',
        'Saree Borders',
      ],
    );

    // Saree Borders must be DESIGN items, not plain saree products.
    final borders =
        ProductCatalog.productsForSubcategory('Sarees', 'Saree Borders');
    expect(borders, isNotEmpty);
    for (final b in borders) {
      expect(b.isDesign, isTrue,
          reason: '${b.id} must be a design, got ${b.productType}');
      expect(b.imagePath.contains('/designs/'), isTrue,
          reason: '${b.id} image must live under designs/, got ${b.imagePath}');
    }

    // The plain border products must no longer surface in the Sarees catalogue.
    final sareeProducts = ProductCatalog.products
        .where((p) =>
            p.category == 'Sarees' &&
            p.subcategory.isNotEmpty &&
            !p.isReadyMade)
        .toList();
    expect(sareeProducts.where((p) => p.id.startsWith('cat_saree_border')),
        isEmpty);
  });

  testWidgets('Wide web-sized viewport renders the grid without layout '
      'assertions', (tester) async {
    for (final width in <double>[800, 1100, 1280, 1400, 1920]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: CategoryCatalogueScreen(
            category: ProductCatalog.categoryDescriptors.first,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The grid (>=760 wide) must build without any layout assertion.
      expect(tester.takeException(), isNull,
          reason: 'Layout assertion at width $width');
      expect(find.byType(Card), findsWidgets);

      // Clean tree before the next width so pumpWidget rebuilds fully.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
      'Tapping a Sarees Saree Borders card opens the existing design flow',
      (tester) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryCatalogueScreen(
          category: ProductCatalog.categoryDescriptors.first,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Every Sarees section renders in the required order; scroll each into
    // view so the assertion doesn't depend on viewport height.
    final verticalList = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    for (final section in [
      'Silk Plain Sarees',
      'Cotton Sarees',
      'Crepe Silk Sarees',
      'Pattu Sarees',
      'Georgette Plain Sarees',
      'Trending Sarees',
      'Saree Borders',
    ]) {
      await tester.dragUntilVisible(
        find.text(section),
        verticalList.first,
        const Offset(0, -400),
        maxIteration: 20,
      );
      await tester.pumpAndSettle();
      expect(find.text(section), findsOneWidget);
    }

    // The last section is Saree Borders; tap its card.
    await tester.ensureVisible(find.text('View').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View').last);
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);

    // A design record opens with the design CTA, not a plain-product checkout.
    expect(find.text('Design'), findsOneWidget);
    expect(find.text('Choose a Product to Print On'), findsOneWidget);

    // It routes into the existing design/customization flow (plain picker).
    await tester.tap(find.text('Choose a Product to Print On'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a Plain Product'), findsOneWidget);
  });
}
