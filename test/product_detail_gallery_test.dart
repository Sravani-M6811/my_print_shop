import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/models/product.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/product_detail_screen.dart';
import 'package:my_print_shop/ui/widgets/catalogue_image.dart';

/// The product detail page shows real photography: a tap-to-swap photo gallery
/// (own image plus sibling photos from the same category/subcategory) instead
/// of a single static image, plus the trust reassurance row.
Future<void> pumpDetail(WidgetTester tester, Product product,
    {Size size = const Size(900, 1400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(home: ProductDetailScreen(product: product)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('detail gallery resolves sibling photos for a base product', () {
    final product = ProductCatalog.products.firstWhere(
      (p) => p.isBase && p.subcategory == 'Silk Plain Sarees',
    );
    final siblings = ProductCatalog.products
        .where((p) =>
            p.category == product.category &&
            p.subcategory == product.subcategory &&
            p.id != product.id)
        .toList();
    expect(siblings, isNotEmpty,
        reason: '${product.name} must have sibling photos in its category');
    expect(siblings.first.imagePath, isNot(product.imagePath));
  });

  testWidgets('gallery renders thumbnails and tapping swaps the hero photo',
      (tester) async {
    final product = ProductCatalog.products.firstWhere(
      (p) => p.isBase && p.subcategory == 'Silk Plain Sarees',
    );

    await pumpDetail(tester, product);

    // Hero + at least one extra thumbnail.
    final heroFinder = find.byKey(const ValueKey('detail-hero'));
    expect(heroFinder, findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-thumb-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-thumb-1')), findsOneWidget);

    String heroPath() => tester
        .widget<CatalogueImage>(heroFinder)
        .imagePath;

    // The hero starts on the product's own photo.
    expect(heroPath(), product.imagePath);

    // The second thumbnail backs a different photo of the same collection.
    final thumb1Image = tester
        .widget<CatalogueImage>(find.descendant(
          of: find.byKey(const ValueKey('gallery-thumb-1')),
          matching: find.byType(CatalogueImage),
        ))
        .imagePath;
    expect(thumb1Image, isNot(product.imagePath),
        reason: 'the gallery should show a second, distinct photo');

    // Tapping the thumbnail swaps the hero to exactly that photo.
    await tester.tap(find.byKey(const ValueKey('gallery-thumb-1')));
    await tester.pumpAndSettle();
    expect(heroPath(), thumb1Image);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail page shows trust chips and no overflow on a phone',
      (tester) async {
    final rm = ProductCatalog.allReadyMadeProducts.first;
    await pumpDetail(tester, rm, size: const Size(320, 568));

    expect(find.text('Free delivery from ₹499'), findsOneWidget);
    expect(find.text('Easy 10-day returns'), findsOneWidget);
    expect(find.text('Secure payment'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('ADD TO CART'),
      find.byType(ProductDetailScreen),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'gallery + trust chips must not overflow a narrow phone');
  });
}
