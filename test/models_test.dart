import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/models/address.dart';
import 'package:my_print_shop/frontend/models/cart_item.dart';
import 'package:my_print_shop/frontend/models/design.dart';
import 'package:my_print_shop/frontend/models/order_item.dart';

void main() {
  group('ProductCatalog', () {
    test('exposes a non-empty catalogue', () {
      expect(ProductCatalog.products, isNotEmpty);
      expect(ProductCatalog.categories, isNotEmpty);
    });

    test('filters products by category', () {
      final shirts = ProductCatalog.productsForCategory('T-Shirts');
      expect(shirts, isNotEmpty);
      expect(shirts.every((p) => p.category == 'T-Shirts'), isTrue);
    });

    test('looks up products by id', () {
      final first = ProductCatalog.products.first;
      expect(ProductCatalog.productById(first.id)?.id, first.id);
      expect(ProductCatalog.productById('does-not-exist'), isNull);
    });

    test('includes the Glass Art category', () {
      expect(ProductCatalog.categories, contains('Glass Art'));
      final glass = ProductCatalog.productsForCategory('Glass Art');
      expect(glass, isNotEmpty);
      expect(glass.every((p) => p.category == 'Glass Art'), isTrue);
    });

    test('preserves all core categories', () {
      for (final c in [
        'Sarees',
        'Saree Borders',
        'T-Shirts',
        'Mugs',
        'Posters',
        'Embroidery',
        'Cardboard',
        'Glass Art',
      ]) {
        expect(ProductCatalog.categories, contains(c), reason: 'missing $c');
      }
    });

    test('search matches name, category and tags (case-insensitive, partial)',
        () {
      for (final p in ProductCatalog.products) {
        expect(ProductCatalog.search(p.name), isNotEmpty);
        expect(ProductCatalog.search(p.category), isNotEmpty);
        if (p.tags.isNotEmpty) {
          expect(ProductCatalog.search(p.tags.first), isNotEmpty);
        }
      }
    });

    test('search matches design descriptions too', () {
      // "floral" appears in several descriptions/tags.
      final floral = ProductCatalog.search('floral');
      expect(floral, isNotEmpty);
      final found = floral.any((p) =>
          p.name.toLowerCase().contains('floral') ||
          p.description.toLowerCase().contains('floral') ||
          p.category.toLowerCase().contains('floral') ||
          p.tags.any((t) => t.toLowerCase().contains('floral')));
      expect(found, isTrue);
    });

    test('featured returns only a curated sample subset', () {
      final featured = ProductCatalog.featured();
      expect(featured, isNotEmpty);
      expect(featured.length, lessThan(ProductCatalog.products.length));
    });
  });

  group('CartItem', () {
    CartItem make({double price = 100, int quantity = 1}) => CartItem(
          id: '1',
          title: 'Test',
          category: 'T-Shirts',
          customText: 'Hi',
          selectedSide: 'Front',
          fontFamily: 'Sans-Serif',
          price: price,
          color: const Color(0xFFFFFFFF),
          quantity: quantity,
        );

    test('lineTotal equals price times quantity', () {
      expect(make(price: 150).lineTotal, 150);
      expect(make(price: 150, quantity: 3).lineTotal, 450);
    });

    test('copyWith changes only the quantity', () {
      final original = make(quantity: 1);
      final updated = original.copyWith(quantity: 4);
      expect(updated.quantity, 4);
      expect(updated.id, original.id);
      expect(updated.price, original.price);
      expect(updated.customText, original.customText);
    });
  });

  group('Design', () {
    test('isCompatibleWith respects compatibleProductIds first', () {
      final d = Design(
        designId: 'd1',
        name: 'Test',
        imagePath: 'assets/x.png',
        category: 'Sarees',
        compatibleProductIds: ['base_tshirt'],
        compatibleCategories: ['Sarees'],
      );
      expect(d.isCompatibleWith('base_tshirt', 'Mugs'), isTrue);
      expect(d.isCompatibleWith('some-other', 'Sarees'), isTrue);
      expect(d.isCompatibleWith('some-other', 'Mugs'), isFalse);
    });

    test('isCompatibleWith falls back to category then own category', () {
      final noDeclarations = Design(
        designId: 'd2',
        name: 'Test',
        imagePath: 'assets/x.png',
        category: 'Posters',
      );
      // No explicit compat -> matches own category only.
      expect(noDeclarations.isCompatibleWith('x', 'Posters'), isTrue);
      expect(noDeclarations.isCompatibleWith('x', 'Mugs'), isFalse);
    });

    test('matches is case-insensitive across name/category/tags', () {
      final d = Design(
        designId: 'd3',
        name: 'Golden Floral',
        imagePath: 'assets/x.png',
        category: 'Sarees',
        tags: const ['wedding', 'zari'],
      );
      expect(d.matches('golden'), isTrue);
      expect(d.matches('SAREES'), isTrue);
      expect(d.matches('zari'), isTrue);
      expect(d.matches('nonsense'), isFalse);
    });
  });

  group('OrderItem', () {
    test('stores address and payment details', () {
      final address = const Address(
        fullName: 'A',
        phone: '123',
        houseFlat: '1',
        streetArea: 'St',
        city: 'C',
        state: 'S',
        pinCode: '000',
      );
      final item = CartItem(
        id: '1',
        title: 'T',
        category: 'Mugs',
        customText: '',
        selectedSide: 'Front',
        fontFamily: 'Sans-Serif',
        price: 200,
        color: const Color(0xFFFFFFFF),
      );
      final order = OrderItem(
        orderId: 'ORD1',
        totalAmount: 200,
        orderDate: DateTime(2026, 1, 1),
        status: 'Print Processing',
        items: [item],
        shippingAddress: address,
        paymentMethod: 'UPI / Online',
        paymentId: 'pay_123',
      );

      expect(order.paymentMethod, 'UPI / Online');
      expect(order.paymentId, 'pay_123');
      expect(order.shippingAddress?.fullName, 'A');
      expect(order.shippingAddress?.fullAddress, contains('C'));
      expect(order.items.single.lineTotal, 200);
    });
  });
}
