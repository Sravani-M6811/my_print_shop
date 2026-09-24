// This test prints the traced legacy design records for visibility.
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_print_shop/frontend/data/product_catalog.dart';

void main() {
  test('Trace design records NOT under designs/ folder', () {
    final all = ProductCatalog.products;
    final notInDesigns = all
        .where((p) => p.isDesign && !p.imagePath.contains('/designs/'))
        .toList();
    print('\n=== ${notInDesigns.length} design records NOT under designs/ folder ===');
    for (final p in notInDesigns) {
      print('  ${p.id}  [${p.category}]  ${p.imagePath}');
      expect(File(p.imagePath).existsSync(), isTrue,
          reason: '${p.id} image missing: ${p.imagePath}');
    }
    // These are the known legacy design records (using products/<cat>/ artwork).
    // Must NOT exceed the known legacy count.
    expect(notInDesigns.length, lessThanOrEqualTo(25));
  });

  test('Sarees have NO Blouse design type', () {
    final types = ProductCatalog.designTypesForCategory('Sarees');
    expect(types, isNot(contains('Blouse')),
        reason: 'Sarees must NOT have Blouse type');
  });

  test('T-Shirts have Anime type', () {
    final types = ProductCatalog.designTypesForCategory('T-Shirts');
    expect(types, contains('Anime'));
  });

  test('Glass Art has Anime type', () {
    final types = ProductCatalog.designTypesForCategory('Glass Art');
    expect(types, contains('Anime'));
  });

  test('Embroidery has Blouse type', () {
    final types = ProductCatalog.designTypesForCategory('Embroidery');
    expect(types, contains('Blouse'));
  });

  test('All 137 base products have images on disk', () {
    final bases = ProductCatalog.allPlainProducts;
    for (final p in bases) {
      expect(File(p.imagePath).existsSync(), isTrue,
          reason: 'base ${p.id} missing ${p.imagePath}');
    }
    expect(bases.length, 137);
  });

  test('Search covers complete catalogue (not just Home categories)', () {
    // Saree Borders is NOT a Home category but exists in catalogue
    final sareeBorders = ProductCatalog.search('zari');
    expect(sareeBorders, isNotEmpty,
        reason: 'search("zari") should find Saree Border designs');

    // All product types searchable
    final allResults = ProductCatalog.search('silk');
    expect(allResults.length, greaterThan(10));
  });

  test('Complete product flow: product → designsForBase returns category-appropriate designs', () {
    // Pick a base product, verify designs returned are from its category
    final baseSaree = ProductCatalog.productById('base_saree')!;
    final designs = ProductCatalog.designsForBase(baseSaree);
    expect(designs, isNotEmpty);
    for (final d in designs) {
      expect(d.category, 'Sarees',
          reason: 'design ${d.id} must be Sarees category');
    }
  });

  test('designTypesForCategory returns Sarees without Blouse', () {
    final types = ProductCatalog.designTypesForCategory('Sarees');
    expect(types, contains('Lace Border'));
    expect(types, contains('Painting'));
    expect(types, contains('Trending Print'));
    expect(types, isNot(contains('Blouse')));
  });
}
