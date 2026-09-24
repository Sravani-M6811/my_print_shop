import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';

/// "Dry-run" catalogue integrity checks — the offline/fallback catalogue that
/// every customer screen reads must never contain a broken image reference, an
/// empty gallery, or a category with no printable products.
///
/// Everything here runs against the *static* catalogue (the merged Firestore
/// view is optional and admin-provided), so the checks are deterministic and
/// network-free.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('categories list covers every shopfront product line', () {
    expect(ProductCatalog.categories, [
      'Sarees',
      'Dress Materials',
      'Saree Borders',
      'T-Shirts',
      'Mugs',
      'Posters',
      'Embroidery',
      'Cardboard',
      'Glass Art',
    ], reason: 'the print-shop categories must be present and ordered');
  });

  test('every product and design image path resolves to a bundled file', () {
    final staticProducts = ProductCatalog.staticProducts;
    final staticDesigns = ProductCatalog.staticDesigns;
    expect(staticProducts, isNotEmpty);
    expect(staticDesigns, isNotEmpty);

    final paths = <String>{
      for (final p in staticProducts)
        if (p.imagePath.isNotEmpty) p.imagePath,
      for (final d in staticDesigns)
        if (d.imagePath.isNotEmpty) d.imagePath,
    };

    expect(paths.length, greaterThan(100),
        reason: 'catalogue must reference a large, real image collection');
    for (final path in paths) {
      if (path.startsWith('http://') || path.startsWith('https://')) continue;
      expect(File(path).existsSync(), isTrue,
          reason: 'bundled image missing on disk: $path');
    }
  });

  test('every category has printable base products and reusable designs', () {
    final bases = ProductCatalog.staticProducts.where((p) => p.isBase).toList();
    final designs = ProductCatalog.staticDesigns;
    for (final category in ProductCatalog.categories) {
      final basesInCategory = bases.where((p) => p.category == category);
      final designsInCategory =
          designs.where((d) => d.category == category);
      expect(basesInCategory.length, greaterThanOrEqualTo(2),
          reason: '$category must expose at least two plain/base products');
      expect(designsInCategory.length, greaterThanOrEqualTo(1),
          reason: '$category must expose at least one reusable design');
    }
  });

  test('every base product has at least one compatible design', () {
    final bases = ProductCatalog.staticProducts.where((p) => p.isBase).toList();
    final designs = ProductCatalog.staticDesigns;
    for (final base in bases) {
      final compatible = designs
          .any((d) => d.isCompatibleWith(base.id, base.category));
      expect(compatible, isTrue,
          reason: '${base.name} (${base.category}) would show an empty '
              'design gallery');
    }
  });

  test('every product carries a positive price and a name', () {
    for (final p in ProductCatalog.staticProducts) {
      expect(p.name.trim(), isNotEmpty, reason: 'product ${p.id} has no name');
      expect(p.basePrice, greaterThan(0),
          reason: 'product ${p.id} (${p.name}) has a non-positive price');
    }
  });

  test('design records reference a real category', () {
    for (final d in ProductCatalog.staticDesigns) {
      expect(ProductCatalog.categories, contains(d.category),
          reason: 'design ${d.designId} references unknown category '
              '${d.category}');
    }
  });

  test('flagship plain products resolve to the requested rows', () {
    final plain = ProductCatalog.staticProducts
        .where((p) => p.isBase && p.subcategory.isNotEmpty)
        .toList();
    expect(plain, isNotEmpty);
    for (final p in plain) {
      expect(File(p.imagePath).existsSync(), isTrue,
          reason: 'base product ${p.id} image missing: ${p.imagePath}');
    }
  });
}
