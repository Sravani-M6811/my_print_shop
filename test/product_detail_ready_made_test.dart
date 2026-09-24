import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_print_shop/frontend/screens/product_detail_screen.dart';
import 'package:my_print_shop/frontend/data/product_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProductDetailScreen - Ready-Made', () {
    testWidgets('shows Ready-Made badge and ADD TO CART button', (tester) async {
      final rmProduct = ProductCatalog.products.firstWhere(
        (p) => p.isReadyMade,
      );

      await tester.pumpWidget(
        MaterialApp(home: ProductDetailScreen(product: rmProduct)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ready-Made'), findsOneWidget);
      expect(find.text('ADD TO CART'), findsOneWidget);
      expect(find.text('CHOOSE A DESIGN'), findsNothing);
    });
  });

  group('ProductDetailScreen - Base', () {
    testWidgets('shows CHOOSE A DESIGN button', (tester) async {
      final baseProduct = ProductCatalog.products.firstWhere(
        (p) => p.isBase,
      );

      await tester.pumpWidget(
        MaterialApp(home: ProductDetailScreen(product: baseProduct)),
      );
      await tester.pumpAndSettle();

      expect(find.text('CHOOSE A DESIGN'), findsOneWidget);
      expect(find.text('ADD TO CART'), findsNothing);
    });
  });
}
