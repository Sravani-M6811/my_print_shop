import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/models/cart_item.dart';
import 'package:my_print_shop/frontend/models/design.dart';
import 'package:my_print_shop/frontend/models/product.dart';
import 'package:my_print_shop/frontend/services/cart_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 design catalogue helpers', () {
    test('trendingProducts returns trending designs (optionally scoped)', () {
      final global = ProductCatalog.trendingProducts();
      expect(global, isNotEmpty);
      expect(global.every((p) => p.isDesign && p.isTrending), isTrue);

      final saree = ProductCatalog.trendingProducts(category: 'Sarees');
      expect(saree.every((p) => p.category == 'Sarees'), isTrue);
    });

    test('designTypesForCategory returns the category design types', () {
      final types = ProductCatalog.designTypesForCategory('Sarees');
      expect(types, isNotEmpty);
      expect(types.every((t) => t.trim().isNotEmpty), isTrue);
    });

    test('productsForDesignType filters by type (optionally category)', () {
      final all = ProductCatalog.productsForDesignType('Nature');
      expect(all, isNotEmpty);
      expect(all.every((p) => p.isDesign && p.designType == 'Nature'), isTrue);

      final scoped =
          ProductCatalog.productsForDesignType('Nature', category: 'T-Shirts');
      expect(scoped.every((p) => p.category == 'T-Shirts'), isTrue);
    });

    test('allDesignTypes is a non-empty, ordered list', () {
      final types = ProductCatalog.allDesignTypes;
      expect(types, isNotEmpty);
      expect(types.toSet().length, types.length);
    });

    test('Design.fromProduct carries the new data-driven fields', () {
      final designProduct =
          ProductCatalog.productsForDesignType('Lace Border').first;
      final design = Design.fromProduct(designProduct);
      expect(design.designType, designProduct.designType);
      expect(design.templateType, designProduct.templateType);
      expect(design.isTrending, designProduct.isTrending);
    });
  });

  group('Phase 2 full-catalogue search', () {
    test('Product.matches searches material/type/keywords, not just name', () {
      final probe = Product(
        id: 'p1',
        name: 'Some Printed Tee',
        category: 'T-Shirts',
        description: '',
        imagePath: '',
        basePrice: 100,
        designType: 'Jersey',
        keywords: const ['cricket', 'sport'],
      );
      expect(probe.matches('cricket'), isTrue);
      expect(probe.matches('jersey'), isTrue);
      expect(probe.matches('sport'), isTrue);
    });

    test('design search covers base, design and ready-made buckets', () {
      expect(ProductCatalog.search('mug').isNotEmpty, isTrue);
      expect(
        ProductCatalog.search('saree').any((p) => p.isDesign),
        isTrue,
      );
    });
  });

  group('Dress Materials stitching persists through serialization', () {
    test('CartItem carries stitching and survives the JSON round-trip', () {
      final item = CartItem(
        id: 'c1',
        title: 'Plain Dress Material · Painting',
        category: 'Dress Materials',
        customText: '',
        selectedSide: 'Front',
        fontFamily: 'Sans-Serif',
        price: 1200,
        color: Colors.black,
        stitching: 'With Stitching',
      );

      final restored = CartService.itemFromMap(CartService.itemToMap(item));
      expect(restored.stitching, 'With Stitching');
    });

    test('stitching is null for non-applicable categories', () {
      final item = CartItem(
        id: 'c2',
        title: 'A Tee',
        category: 'T-Shirts',
        customText: '',
        selectedSide: 'Front',
        fontFamily: 'Sans-Serif',
        price: 500,
        color: Colors.black,
      );
      expect(item.stitching, isNull);
    });
  });
}
