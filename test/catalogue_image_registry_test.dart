import 'package:flutter_test/flutter_test.dart';

import 'package:my_print_shop/frontend/models/catalogue_image.dart';
import 'package:my_print_shop/admin/services/catalogue_image_registry.dart';

void main() {
  final registry = CatalogueImageRegistry.instance;

  test('registry is seeded from the shipped catalogue', () {
    expect(registry.total, greaterThan(0));
    expect(registry.categoryCounts, isNotEmpty);
  });

  test('suggestion paths for known categories are non-empty', () {
    for (final category in ['Sarees', 'T-Shirts', 'Mugs', 'Posters']) {
      expect(registry.suggestionPathsFor(category), isNotEmpty,
          reason: '$category should have quick-pick images');
    }
  });

  test('search matches tags, paths and categories', () {
    final byTag = registry.search('silk');
    final byPath = registry.search('assets/images/');
    expect(byTag, isNotEmpty);
    expect(byPath.length, greaterThanOrEqualTo(byTag.isNotEmpty ? 1 : 0));
  });

  test('registering a duplicate path is a no-op', () {
    final before = registry.total;
    final existing = registry.all().first;
    registry.register(existing);
    expect(registry.total, before);
  });

  test('forCategory filters by type and active status', () {
    final sarees = registry.forCategory('Sarees');
    expect(sarees, isNotEmpty);
    final activeOnly = sarees.every((i) => i.isActive);
    expect(activeOnly, isTrue);
    final types = sarees.map((i) => i.type).toSet();
    expect(types.difference({'product', 'design'}), isEmpty);
  });

  test('a remote image is detected correctly', () {
    const info = CatalogueImageInfo(
      id: 'img_test',
      path: 'https://cdn.example.com/1.jpg',
      categoryId: 'Sarees',
      source: CatalogueImageSource.remote,
    );
    expect(info.isRemote, isTrue);
    expect(info.matches('cdn'), isTrue);
    expect(info.matches('missing'), isFalse);
  });
}
