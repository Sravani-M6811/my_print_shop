import 'package:flutter_test/flutter_test.dart';
import 'package:my_print_shop/frontend/models/design.dart';
import 'package:my_print_shop/frontend/models/product.dart';
import 'package:my_print_shop/admin/services/catalogue_service.dart';

Product _sampleProduct({String id = 'prod_x'}) => Product(
      id: id,
      name: 'Plain Oversized T-Shirt',
      category: 'Oversized T-Shirts',
      description: 'Boxy fit',
      basePrice: 499,
      imagePath: 'assets/images/products/tshirts/oversized_plain.jpg',
      subcategory: 'Oversized',
      productType: 'base',
      material: 'Cotton',
      availableSizes: const ['S', 'M', 'L', 'XL'],
      tags: const ['oversized'],
      designType: '',
      availability: true,
    );

Design _sampleDesign({String designId = 'design_x'}) => Design(
      designId: designId,
      name: 'Abstract Art Print',
      category: 'Sarees',
      imagePath: 'assets/images/designs/sarees/abstract.jpg',
      tags: const ['abstract', 'art'],
      description: 'Bold brush strokes',
      designType: 'Abstract',
      isTrending: true,
      availability: true,
    );

void _expectProductRoundTrip(Product p) {
  final restored =
      CatalogueService.productFromMap(CatalogueService.productToMap(p));
  expect(restored.id, p.id);
  expect(restored.name, p.name);
  expect(restored.category, p.category);
  expect(restored.subcategory, p.subcategory);
  expect(restored.productType, p.productType);
  expect(restored.description, p.description);
  expect(restored.basePrice, p.basePrice);
  expect(restored.imagePath, p.imagePath);
  expect(restored.material, p.material);
  expect(restored.availableSizes, p.availableSizes);
  expect(restored.tags, p.tags);
  expect(restored.availability, p.availability);
}

void _expectDesignRoundTrip(Design d) {
  final restored =
      CatalogueService.designFromMap(CatalogueService.designToMap(d));
  expect(restored.designId, d.designId);
  expect(restored.name, d.name);
  expect(restored.category, d.category);
  expect(restored.imagePath, d.imagePath);
  expect(restored.tags, d.tags);
  expect(restored.description, d.description);
  expect(restored.availability, d.availability);
  expect(restored.isTrending, d.isTrending);
  expect(restored.supportsCustomization, d.supportsCustomization);
  expect(restored.supportsUpload, d.supportsUpload);
}

void main() {
  group('CatalogueService serialization', () {
    test('product round-trips all editable fields through toMap/fromMap', () {
      _expectProductRoundTrip(_sampleProduct());
    });

    test('design round-trips all editable fields through toMap/fromMap', () {
      _expectDesignRoundTrip(_sampleDesign());
    });

    test('absent fields get safe defaults', () {
      final restored = CatalogueService.productFromMap(const {});
      expect(restored.id, '');
      expect(restored.basePrice, 0);
      expect(restored.availability, true);
      expect(restored.variants, isEmpty);
      expect(CatalogueService.designFromMap(const {}).designId, '');
    });
  });

  group('mergeProducts', () {
    test('overrides replace base records by id and keep base order', () {
      final base = [
        _sampleProduct(id: 'a'),
        _sampleProduct(id: 'b'),
        _sampleProduct(id: 'c'),
      ];
      final remote = [base[1].copyWith(name: 'Renamed B', availability: false)];
      final merged = CatalogueService.mergeProducts(base, remote);
      expect(merged.length, 3);
      expect(merged[0].id, 'a');
      expect(merged[1].id, 'b');
      expect(merged[1].name, 'Renamed B');
      expect(merged[1].availability, false);
      expect(merged[2].id, 'c');
    });

    test('remote records without a base counterpart are appended', () {
      final base = [_sampleProduct(id: 'a')];
      final remote = [
        _sampleProduct(id: 'a').copyWith(name: 'Changed'),
        _sampleProduct(id: 'brand_new'),
      ];
      final merged = CatalogueService.mergeProducts(base, remote);
      expect(merged.length, 2);
      expect(merged[0].id, 'a');
      expect(merged[0].name, 'Changed');
      expect(merged[1].id, 'brand_new');
    });

    test('empty remote leaves base untouched', () {
      final base = [_sampleProduct()];
      final merged = CatalogueService.mergeProducts(base, const <Product>[]);
      expect(merged.length, 1);
      expect(identical(merged.first, base.first), isTrue);
    });
  });

  group('mergeDesigns', () {
    test('overrides replace and new designs are appended', () {
      final base = [_sampleDesign(designId: 'd1')];
      final remote = [
        _sampleDesign(designId: 'd1').copyWith(isTrending: true),
        _sampleDesign(designId: 'd2'),
      ];
      final merged = CatalogueService.mergeDesigns(base, remote);
      expect(merged.length, 2);
      expect(merged[0].designId, 'd1');
      expect(merged[0].isTrending, true);
      expect(merged[1].designId, 'd2');
    });

    test('empty remote leaves base untouched', () {
      final base = [_sampleDesign()];
      final merged = CatalogueService.mergeDesigns(base, const <Design>[]);
      expect(merged.length, 1);
      expect(identical(merged.first, base.first), isTrue);
    });
  });

  group('validation helpers', () {
    test('required rejects blank/whitespace and trims values', () {
      expect(CatalogueService.required('', 'Product name'), 'Product name is required');
      expect(CatalogueService.required('   ', 'Product name'), 'Product name is required');
      expect(CatalogueService.required('  Name  ', 'Product name'), null);
      expect(CatalogueService.required(null, 'Product name'), 'Product name is required');
    });

    test('validatePrice accepts non-negative decimals and rejects junk', () {
      expect(CatalogueService.validatePrice('499'), isNull);
      expect(CatalogueService.validatePrice('499.50'), isNull);
      expect(CatalogueService.validatePrice('0'), isNull);
      expect(CatalogueService.validatePrice('abc'), isNotNull);
      expect(CatalogueService.validatePrice('-5'), isNotNull);
      expect(CatalogueService.validatePrice(''), isNotNull);
    });

    test('validateImage accepts bundled assets and http(s) urls', () {
      expect(CatalogueService.validateImage('assets/images/products/m/1.jpg'), isNull);
      expect(CatalogueService.validateImage('https://img.example/x.png'), isNull);
      expect(CatalogueService.validateImage('http://img.example/x.png'), isNull);
      expect(CatalogueService.validateImage('assets/x.png'), isNull);
      expect(CatalogueService.validateImage(''), isNotNull);
    });

    test('validateCategory rejects an empty selection', () {
      expect(CatalogueService.validateCategory('Sarees'), isNull);
      expect(CatalogueService.validateCategory(''), 'Select a category');
      expect(CatalogueService.validateCategory(null), 'Select a category');
    });
  });

  group('soft-delete semantics (copyWith)', () {
    test('copyWith sets availability false for products', () {
      final deactivated = _sampleProduct().copyWith(availability: false);
      expect(deactivated.availability, false);
      expect(deactivated.name, _sampleProduct().name);
    });

    test('copyWith sets availability false for designs', () {
      final deactivated = _sampleDesign().copyWith(availability: false);
      expect(deactivated.availability, false);
      expect(deactivated.designId, _sampleDesign().designId);
    });
  });
}

