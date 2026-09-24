import 'package:flutter_test/flutter_test.dart';

import 'package:my_print_shop/frontend/services/category_image_catalog.dart';

void main() {
  group('CategoryImageCatalog', () {
    test('categoryImage returns the seeded Pexels photo for known categories',
        () {
      final path = CategoryImageCatalog.categoryImage(
        categoryName: 'Sarees',
        bundledPath: 'assets/images/products/sarees/plain_maroon.jpg',
      );
      expect(path, startsWith('https://images.pexels.com/photos/5447529/'));
    });

    test('banner keeps the bundled asset for unknown categories', () {
      const bundled = 'assets/images/products/sarees/plain_maroon.jpg';
      expect(
        CategoryImageCatalog.categoryImage(
            categoryName: 'Watches', bundledPath: bundled),
        bundled,
      );
    });

    test('subcategoryImage prefers the sub-category seeded photo', () {
      final path = CategoryImageCatalog.subcategoryImage(
        categoryName: 'T-Shirts',
        subcategoryName: 'Half Sleeve',
        bundledPath: 'assets/images/products/tshirts/plain.jpg',
      );
      expect(path, startsWith('https://images.pexels.com/photos/4440572/'));
    });

    test('every catalogued sub-category resolves to its own seeded photo or a '
        'category photo, never the bundled asset', () {
      const known = {
        'Sarees': {
          'Silk Plain': 7956629,
          'Cotton': 32459983,
          'Crepe Silk': 4814062,
          'Pattu': 10317113,
          'Other': 6571744,
        },
        'Saree Borders': {
          'Lace': 8752432,
          'Traditional': 8710793,
          'Decorative': 13446351,
          'Other': 12991912,
        },
        'T-Shirts': {
          'Half Sleeve': 4440572,
          'Full Sleeve': 7764063,
          "Women's": 31041770,
          'Hoodies': 5840463,
          'Plain Colour': 8146450,
          'Plain White': 18257675,
        },
        'Mugs': {
          'Small': 29783602,
          'Large': 11390372,
          'Other': 39361143,
        },
        'Posters': {
          'Small': 4065192,
          'Medium': 19765934,
          'Large': 11556402,
          'XL Flex': 6620972,
          'Other': 14122051,
        },
        'Embroidery': {
          'Floral': 30295968,
          'Traditional': 32480210,
          'Names': 29098234,
          'Borders': 29893325,
          'Figures': 7523526,
          'Devotional': 35977513,
          'Embroidery Bases': 8465947,
        },
        'Cardboard': {
          'Standee': 5872172,
          'Event': 7509508,
          'Display': 11835350,
          'Template': 7464189,
          'Boards by Size': 8580789,
        },
        'Glass Art': {
          'Painting': 34368490,
          'Decorative': 37879709,
          'Floral': 35225713,
          'Devotional': 39176222,
          'Abstract': 14787004,
          'Plain Glass': 1407487,
        },
        'Dress Materials': {
          'Silk': 4614231,
          'Cotton': 9824794,
          'Crepe Silk': 4862901,
          'All Dress Materials': 6487380,
        },
      };

      known.forEach((category, subs) {
        subs.forEach((subname, photoId) {
          final path = CategoryImageCatalog.subcategoryImage(
            categoryName: category,
            subcategoryName: subname,
            bundledPath: 'bundled.jpg',
          );
          expect(path, contains('pexels-photo-$photoId'),
              reason: '$category / $subname should resolve to photo $photoId');
        });
      });
    });

    test('unknown sub-category folds to the category photo, not the bundle', () {
      final path = CategoryImageCatalog.subcategoryImage(
        categoryName: 'Posters',
        subcategoryName: 'Unknown Size',
        bundledPath: 'bundled.jpg',
      );
      expect(path, startsWith('https://images.pexels.com/photos/7247514/'));
    });

    test('unknown category falls back to the bundled asset', () {
      expect(
        CategoryImageCatalog.subcategoryImage(
          categoryName: 'Watches',
          subcategoryName: 'Analog',
          bundledPath: 'bundled.jpg',
        ),
        'bundled.jpg',
      );
    });
  });
}
