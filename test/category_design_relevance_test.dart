import 'package:flutter_test/flutter_test.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';

/// Phase 2C — category-specific design filtering:
/// when a customer picks a plain/base product (or browses one category) and
/// reaches "CHOOSE A DESIGN", only designs that genuinely belong on that
/// product/category are offered. T-shirt-only artwork must never be offered
/// for a saree, mug or poster, while the global "All Designs" mode stays
/// complete and search keeps working.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plain/Base Product -> design choice is category-relevant', () {
    test('T-Shirts base product never offers Nature/Portrait tee designs', () {
      final tee = ProductCatalog.productById('base_tshirt')!;
      final designs = ProductCatalog.designsForBase(tee);
      expect(designs, isNotEmpty);
      for (final d in designs) {
        expect(d.category, 'T-Shirts',
            reason: '${d.id} leaked across categories into T-Shirts');
      }
      // Phase 2C: nature/pre-made fashion-print tees are not offered when the
      // customer asked to print ON a plain T-shirt.
      expect(designs.any((p) => p.designType == 'Nature'), isFalse,
          reason: 'Nature tees must not appear for a plain T-shirt');
      expect(designs.any((p) => p.designType == 'Portrait'), isFalse,
          reason: 'Portrait tees must not appear for a plain T-shirt');
      // But curated T-shirt content stays fully available.
      final types = designs.map((p) => p.designType).toSet();
      expect(types, containsAll(['Typography', 'Anime', 'Sports', 'Sticker']));
    });

    test('every base product only offers its own category designs', () {
      for (final base in ProductCatalog.baseProducts) {
        final designs = ProductCatalog.designsForBase(base);
        if (designs.isEmpty) continue;
        for (final d in designs) {
          expect(
            ProductCatalog.isProductDesignCategoryRelevant(d, base.category),
            isTrue,
            reason: '${d.id} is not relevant for ${base.name} '
                '(${base.category})',
          );
        }
      }
    });

    test('a T-shirt-only design never appears for the other printable '
        'categories', () {
      for (final category in ProductCatalog.categoryDesignRelevance.keys) {
        if (category == 'T-Shirts') continue;
        final designs = ProductCatalog.productsForCategory(category);
        for (final d in designs) {
          expect(
            d.compatibleCategories.contains('T-Shirts') &&
                !d.compatibleCategories.contains(category),
            isFalse,
            reason: '${d.id} is marked T-shirt-only but was offered for '
                '$category',
          );
          expect(
            ProductCatalog.isProductDesignCategoryRelevant(d, category),
            isTrue,
            reason: '${d.id} should be relevant for $category',
          );
        }
      }
    });
  });

  group('Category design libraries are curated per category', () {
    test('T-Shirts library excludes Nature and Portrait design types', () {
      final types = ProductCatalog.designTypesForCategory('T-Shirts');
      expect(types, containsAll(['Typography', 'Anime', 'Sports']));
      expect(types, isNot(contains('Nature')));
      expect(types, isNot(contains('Portrait')));
    });

    test('Sarees library keeps borders, paintings and trending prints', () {
      final types = ProductCatalog.designTypesForCategory('Sarees');
      expect(types, containsAll(['Lace Border', 'Painting', 'Trending Print']));
      expect(types, isNot(contains('Mug Art')));
      expect(types, isNot(contains('Hot Mug')));
    });

    test('Mugs library keeps stickers, labels, hot-mug and mug-art types', () {
      final types = ProductCatalog.designTypesForCategory('Mugs');
      expect(types, containsAll(['Sticker', 'Label', 'Hot Mug', 'Mug Art']));
      expect(types, isNot(contains('Jersey')));
    });

    test('Cardboard library is template-driven only', () {
      final types = ProductCatalog.designTypesForCategory('Cardboard');
      expect(types, contains('Template'));
    });

    test('Embroidery keeps its embroidery-native content', () {
      final types = ProductCatalog.designTypesForCategory('Embroidery');
      expect(types, containsAll(['Floral', 'Traditional', 'Portrait', 'Emblem']));
      expect(types, contains('Blouse'),
          reason: 'embroidered blouse artwork stays relevant');
      expect(types, isNot(contains('Sticker')));
      expect(types, isNot(contains('Hot Mug')));
    });

    test('Glass Art keeps floral, devotional and decorative designs', () {
      final types = ProductCatalog.designTypesForCategory('Glass Art');
      expect(types, containsAll(['Floral', 'Devotional', 'Decorative']));
    });

    test('every category still offers 30+ relevant designs', () {
      for (final category in ProductCatalog.categories) {
        final rows = ProductCatalog.customerDesigns(category: category);
        expect(rows.length, greaterThanOrEqualTo(30),
            reason: '$category must keep at least 30 relevant designs');
      }
    });

    test('designTypesForCategory chips match the gallery sections', () {
      for (final category in ProductCatalog.categories) {
        final chips = ProductCatalog.designTypesForCategory(category).toSet();
        final sections = ProductCatalog
            .groupDesignsByType(
                ProductCatalog.customerDesigns(category: category))
            .map((g) => g.title)
            .where((t) => t != 'More Designs')
            .toSet();
        expect(chips, sections,
            reason: '$category type chips must match rendered sections');
      }
    });
  });

  group('Global All-Designs mode and explicit filters are preserved', () {
    test('global catalogue is never relevance-filtered', () {
      final global = ProductCatalog.customerDesigns();
      final natureTeenTShirt = ProductCatalog.productsForDesignType('Nature')
          .any((p) => p.category == 'T-Shirts');
      expect(natureTeenTShirt, isTrue,
          reason: 'global catalogue must keep T-shirt Nature designs');
      expect(global.length, greaterThan(
          ProductCatalog.customerDesigns(category: 'T-Shirts').length));
    });

    test('explicit type/theme requests are honoured for any category', () {
      // The curated type/theme queries evaluated even for excluded types must
      // still resolve to real records (filters are AND-ed over the data, never
      // pre-empted by the relevance rule).
      final natureTyped =
          ProductCatalog.customerDesigns(category: 'T-Shirts', designType: 'Nature');
      expect(natureTyped, isNotEmpty);
      final natureThemed =
          ProductCatalog.customerDesigns(category: 'T-Shirts', theme: 'Nature');
      expect(natureThemed, isNotEmpty);
    });

    test('global design types and theme galleries stay complete', () {
      expect(ProductCatalog.allDesignTypes, contains('Nature'));
      expect(ProductCatalog.designThemes, isNotEmpty);
      expect(ProductCatalog.customerDesigns(theme: 'Nature'), isNotEmpty);
      expect(ProductCatalog.productsForDesignType('Portrait'), isNotEmpty);
    });

    test('search keeps working in every category', () {
      const queries = {
        'Sarees': 'lace',
        'Saree Borders': 'mirror',
        'T-Shirts': 'cricket',
        'Mugs': 'coffee',
        'Posters': 'motivational',
        'Embroidery': 'floral',
        'Cardboard': 'wedding',
        'Glass Art': 'flowers',
      };
      queries.forEach((category, query) {
        final results =
            ProductCatalog.filteredSearch(query, category: category);
        expect(results, isNotEmpty,
            reason: 'search("$query") in $category must still resolve');
      });
    });
  });
}
