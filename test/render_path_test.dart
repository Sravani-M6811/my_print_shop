import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/models/product.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/category_catalogue_screen.dart';
import 'package:my_print_shop/frontend/screens/home_screen.dart';
import 'package:my_print_shop/frontend/screens/product_detail_screen.dart';

/// Verifies the REAL rendering path of the requested rows:
///   1. every flagship [Product.imagePath] must resolve AND DECODE through the
///      actual asset bundle (the same loader the running app uses), and
///   2. the real Home -> [CategoryCatalogueScreen] flow must build each row
///      title with its product card, without ever falling into the silent
///      errorBuilder placeholder, and back-navigation must return to the
///      previous screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final requested = <(String, String)>[
    ('Saree Borders', 'Plain Saree Borders'),
    ('Saree Borders', 'Plain Contrast Borders'),
    ('Saree Borders', 'Plain Mirror Borders'),
    ('T-Shirts', 'Plain T-Shirts'),
    ('T-Shirts', 'Plain Oversized T-Shirts'),
    ('T-Shirts', 'Plain Polo T-Shirts'),
    ('Mugs', 'Plain Mugs'),
    ('Mugs', 'Plain Magic Mugs'),
    ('Mugs', 'Plain Travel Mugs'),
    ('Posters', 'Plain Posters'),
    ('Posters', 'Blank Canvas Posters'),
    ('Embroidery', 'Plain Embroidery Base'),
    ('Embroidery', 'Plain Fabric Base'),
    ('Cardboard', 'Plain Cardboard'),
    ('Cardboard', 'Blank Standee'),
    ('Glass Art', 'Plain Glass'),
    ('Glass Art', 'Plain Glass Frame'),
  ];

  Future<void> proveImageDecodes(String key) async {
    final stream = AssetImage(key).resolve(ImageConfiguration.empty);
    final completer = Completer<void>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool syncCall) {
        info.image.dispose();
        completer.complete();
      },
      onError: (Object error, StackTrace? stackTrace) {
        completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('decode timed out for $key'),
    );
    stream.removeListener(listener);
  }

  test('all 17 requested flagship images resolve AND decode', () async {
    for (final (category, subcategory) in requested) {
      final product = ProductCatalog.products.firstWhere(
        (p) => p.category == category && p.subcategory == subcategory,
      );
      await proveImageDecodes(product.imagePath);
    }
  });

  final categories = requested.map((e) => e.$1).toSet().toList();

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpCatalogue(WidgetTester tester, String category) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          home: CategoryCatalogueScreen(
            category: ProductCatalog.categoryDescriptors
                .firstWhere((d) => d.name == category),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seeRow(WidgetTester tester, String row,
      {bool expectCard = true}) async {
    // The row's section header is a bold 20px Text with the subcategory title.
    final header = find.byWidgetPredicate((w) =>
        w is Text && w.data == row && (w.style?.fontSize ?? 0) >= 20);
    for (var attempt = 0; attempt < 12; attempt++) {
      await tester.pumpAndSettle();
      if (header.evaluate().isNotEmpty) {
        await tester.ensureVisible(header.first);
        await tester.pumpAndSettle();
        expect(header, findsOneWidget,
            reason: 'catalogue must show row header "$row"');
        // The card itself is built underneath the header.
        expect(find.text(row).evaluate().length, greaterThanOrEqualTo(1),
            reason: 'a product card must be built under "$row"');
        expect(find.byIcon(Icons.image_not_supported), findsNothing,
            reason: 'no silent placeholder for "$row"');
        return;
      }
      await tester.drag(
          find.byType(CategoryCatalogueScreen), const Offset(0, -350));
    }
    fail('row "$row" never appeared while scrolling the catalogue');
  }

  testWidgets('Home -> T-Shirts catalogue shows image card; back returns home',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('T-Shirts').first);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCatalogueScreen), findsOneWidget);

    await seeRow(tester, 'Plain T-Shirts');
    expect(find.text('Plain T-Shirt'), findsOneWidget);
    expect(find.textContaining('From ₹399'), findsOneWidget);

    final images = find.descendant(
      of: find.byType(CategoryCatalogueScreen),
      matching: find.byType(Image),
    );
    expect(images, findsWidgets);
    expect(find.byIcon(Icons.image_not_supported), findsNothing);

    // The card's CTA opens the product detail.
    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);

    // The AppBar back arrow returns to the exact previous screen.
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCatalogueScreen), findsOneWidget);

    // And from the catalogue, back again returns to Home.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Home grid now opens the Saree Borders catalogue with its rows',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Saree Borders').first);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCatalogueScreen), findsOneWidget);
    await seeRow(tester, 'Plain Saree Borders');
    await seeRow(tester, 'Plain Contrast Borders');
    await seeRow(tester, 'Plain Mirror Borders');
    expect(find.byIcon(Icons.image_not_supported), findsNothing);
  });

  for (final category in categories) {
    testWidgets('$category shows every requested row with a product card',
        (tester) async {
      await pumpCatalogue(tester, category);
      final rows = requested
          .where((e) => e.$1 == category)
          .map((e) => e.$2)
          .toList();
      for (final row in rows) {
        await seeRow(tester, row);
      }
      expect(find.byType(Image), findsWidgets);
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
    });
  }
}
