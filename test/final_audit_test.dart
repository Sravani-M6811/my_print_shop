// This audit test intentionally prints its findings so the audit results are
// readable in CI output; the print lint is disabled for this file only.
// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_print_shop/frontend/data/product_catalog.dart';

void main() {
  final issues = <String>[];

  setUpAll(() {
    // 1. 8 required home categories present.
    const requiredNames = [
      'Sarees', 'T-Shirts', 'Mugs', 'Posters', 'Embroidery',
      'Cardboards', 'Glass Art', 'Dress Materials',
    ];
    final descNames =
        ProductCatalog.categoryDescriptors.map((d) => d.name.trim()).toList();
    print('\n=== 1. Category descriptors (${descNames.length}) ===');
    for (final n in descNames) print('   - $n');

    bool normEq(String a, String b) {
      String norm(String x) =>
          x.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      return norm(a) == norm(b) ||
          norm(a) == norm(b.replaceFirst(RegExp(r's$'), ''));
    }

    for (final r in requiredNames) {
      final found = descNames.any((n) => normEq(n, r));
      print('   required $r -> ${found ? 'FOUND' : 'MISSING'}');
      if (!found) issues.add('Home category missing: $r');
    }

    // Descriptor images exist on disk.
    for (final d in ProductCatalog.categoryDescriptors) {
      final ok = File(d.imagePath).existsSync();
      print('   desc ${d.name}: image exists=$ok (${d.imagePath})');
      if (!ok) issues.add('descriptor image missing ${d.imagePath}');
    }

    // 2. Base/plain products.
    final baseProds = ProductCatalog.allPlainProducts;
    print('\n=== 2. Base/plain products (${baseProds.length}) ===');
    int baseMissing = 0, baseInDesigns = 0;
    for (final p in baseProds) {
      if (!File(p.imagePath).existsSync()) {
        baseMissing++;
        issues.add('base ${p.id} missing image ${p.imagePath}');
      }
      if (p.imagePath.contains('/designs/')) baseInDesigns++;
    }
    print('   missing: $baseMissing, in designs/: $baseInDesigns');

    print('   Featured plain products (Home "Create Your Own"):');
    for (final p in ProductCatalog.featuredPlainProducts()) {
      final ok = File(p.imagePath).existsSync();
      print('   - ${p.id} [${p.category}] exists=$ok');
      if (!ok) issues.add('featured plain ${p.id} missing ${p.imagePath}');
    }

    // 3. Ready-made.
    print('\n=== 3. Ready-made products ===');
    for (final p in ProductCatalog.allReadyMadeProducts) {
      final ok = File(p.imagePath).existsSync();
      print('   - ${p.id} [${p.category}] exists=$ok');
      if (!ok) issues.add('readyMade ${p.id} missing ${p.imagePath}');
      // Must bypass design selection: productType readyMade.
      assert(p.productType == 'readyMade', '${p.id} is not readyMade');
    }
    print('   ${ProductCatalog.allReadyMadeProducts.length} ready-made records verified');

    // 4. Product/Design asset separation.
    final all = ProductCatalog.products;
    int prodInDesigns = 0, designInProducts = 0;
    final missing = <String>[];
    for (final p in all) {
      if (!File(p.imagePath).existsSync()) missing.add('${p.id}->${p.imagePath}');
      if (p.isBase || p.isReadyMade) {
        if (p.imagePath.contains('/designs/')) prodInDesigns++;
      } else if (p.isDesign) {
        if (!p.imagePath.contains('/designs/')) designInProducts++;
      }
    }
    print('\n=== 4. Asset separation ===');
    print('   total catalogue: ${all.length}');
    print('   missing files: ${missing.length}');
    for (final m in missing.take(20)) print('     MISSING $m');
    print('   base/readyMade in designs/: $prodInDesigns');
    print('   designs NOT in designs/: $designInProducts');

    // 5. Category-specific design filtering.
    print('\n=== 5. Category design filtering ===');
    for (final cat in ProductCatalog.categoryDescriptors.map((d) => d.name)) {
      final ds = ProductCatalog.designsForCategory(cat);
      final stray = ds.where((d) => d.category != cat).length;
      final bases = ProductCatalog.plainProductsForCategory(cat);
      final baseName = bases.isNotEmpty ? bases.first.id : 'NONE';
      print('   $cat: ${ds.length} designs, stray=$stray, base=$baseName');
      if (stray > 0) issues.add('designsForCategory($cat) has $stray stray');
    }

    // 6. Design types per category (actual model values).
    print('\n=== 6. designTypesForCategory ===');
    for (final cat in ProductCatalog.categoryDescriptors.map((d) => d.name)) {
      final types = ProductCatalog.designTypesForCategory(cat);
      print('   $cat: $types');
    }
    print('   allDesignTypes: ${ProductCatalog.allDesignTypes}');

    // 7. Global Design catalogue.
    final allDesigns = ProductCatalog.designs;
    print('\n=== 7. Global Design catalogue ===');
    print('   total designs: ${allDesigns.length}');
    final badIds = allDesigns.where((d) =>
        d.designId.startsWith('base_') ||
        d.designId.startsWith('rm_'));
    print('   designs with base_/rm_ ids: ${badIds.length}');

    // 8. Search against complete catalogue.
    print('\n=== 8. Search ===');
    final floralResults = ProductCatalog.search('floral');
    print('   search("floral"): ${floralResults.length} results');
    final animeResults = ProductCatalog.search('anime');
    print('   search("anime"): ${animeResults.length} results');

    print('\n=== ISSUES FOUND (${issues.length}) ===');
    for (final i in issues) print('  ! $i');
  });

  test('Catalogue integrity: no issues found', () {
    expect(issues, isEmpty);
  });
}
