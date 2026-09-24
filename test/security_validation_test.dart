import 'package:flutter_test/flutter_test.dart';

import 'package:my_print_shop/admin/services/catalogue_service.dart';

void main() {
  group('CatalogueService validation hardening', () {
    test('maxLength rejects values that exceed the character limit', () {
      final longString = List.filled(13, 'a').join();
      final atLimit = List.filled(12, 'a').join();
      expect(CatalogueService.maxLength(longString, 'Name', 12), isNotNull);
      expect(CatalogueService.maxLength(atLimit, 'Name', 12), isNull);
      // Empty / null pass through — the field is optional.
      expect(CatalogueService.maxLength('', 'Name', 12), isNull);
      expect(CatalogueService.maxLength(null, 'Name', 12), isNull);
    });

    test('validatePrice caps unreasonably large prices', () {
      expect(CatalogueService.validatePrice('9999999'), isNotNull);
      expect(CatalogueService.validatePrice('1000000'), isNull);
      expect(CatalogueService.validatePrice('499'), isNull);
      expect(CatalogueService.validatePrice('abc'), isNotNull);
    });

    test('validateImage rejects overly long references', () {
      final longAsset = 'assets/${List.filled(2100, 'a').join()}';
      final longUrl =
          'https://img.example/${List.filled(2100, 'x').join()}.png';
      expect(CatalogueService.validateImage(longAsset), isNotNull);
      expect(CatalogueService.validateImage(longUrl), isNotNull);
      expect(
        CatalogueService.validateImage(
            'assets/images/products/m/1.jpg'),
        isNull,
      );
    });
  });
}
