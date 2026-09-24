import 'package:flutter_test/flutter_test.dart';
import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/models/design.dart';
import 'package:my_print_shop/frontend/models/product.dart';
import 'package:my_print_shop/frontend/services/customer_catalogue.dart';

import 'helpers/fake_catalogue_repository.dart';

Product _sampleBaseProduct({String id = 'base_new'}) => Product(
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

Product _sampleDesignProduct({
  String id = 'brand_new_design',
  String name = 'Brand New Saree Design',
}) =>
    Product(
      id: id,
      name: name,
      category: 'Sarees',
      description: 'Freshly published from the admin panel',
      basePrice: 899,
      imagePath: 'assets/images/designs/sarees/new.jpg',
      subcategory: '',
      productType: '',
      material: 'Silk',
      tags: const ['new'],
      designType: 'Modern',
      availability: true,
    );

Design _sampleRemoteDesign({String designId = 'design_x'}) => Design(
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

void main() {
  tearDown(() {
    // Never leak test data into the shared singleton used by other suites.
    CustomerCatalogue.instance.debugResetForTesting();
  });

  group('CustomerCatalogue refresh/merge', () {
    test('serves the static catalogue when Firestore is unavailable', () async {
      final repo = FakeCatalogueRepository()
        ..failProductsFetch = true
        ..failDesignsFetch = true;
      final catalogue = CustomerCatalogue(repository: repo);
      await catalogue.refresh();

      expect(catalogue.products.length, ProductCatalog.staticProducts.length);
      expect(catalogue.designs.length, ProductCatalog.staticDesigns.length);
      expect(catalogue.products, isNotEmpty);
      expect(catalogue.products, isNot(same(ProductCatalog.staticProducts)));
    });

    test('remote override replaces a static product', () async {
      final staticId = ProductCatalog.staticProducts.first.id;
      final remote = ProductCatalog.staticProducts.first
          .copyWith(name: 'Renamed Saree', basePrice: 999);
      final repo = FakeCatalogueRepository()..products.add(remote);
      final catalogue = CustomerCatalogue(repository: repo);
      await catalogue.refresh();

      final merged =
          catalogue.products.firstWhere((p) => p.id == staticId);
      expect(merged.name, 'Renamed Saree');
      expect(merged.basePrice, 999);
      expect(catalogue.products.length, ProductCatalog.staticProducts.length);
    });

    test('remote override replaces a static design', () async {
      final staticId = ProductCatalog.staticDesigns.first.designId;
      final remote = ProductCatalog.staticDesigns.first
          .copyWith(name: 'Renamed Saree Design');
      final repo = FakeCatalogueRepository()..designs.add(remote);
      final catalogue = CustomerCatalogue(repository: repo);
      await catalogue.refresh();

      final merged = catalogue.designs.firstWhere((d) => d.designId == staticId);
      expect(merged.name, 'Renamed Saree Design');
      expect(catalogue.designs.length, ProductCatalog.staticDesigns.length);
    });

    test('new remote products are appended', () async {
      final repo = FakeCatalogueRepository()
        ..products.add(_sampleDesignProduct(id: 'brand_new_design'));
      final catalogue = CustomerCatalogue(repository: repo);
      await catalogue.refresh();

      expect(catalogue.products.any((p) => p.id == 'brand_new_design'), isTrue);
      expect(catalogue.products.length,
          ProductCatalog.staticProducts.length + 1);
    });

    test('new remote designs are appended', () async {
      final repo = FakeCatalogueRepository()
        ..designs.add(_sampleRemoteDesign(designId: 'design_x'));
      final catalogue = CustomerCatalogue(repository: repo);
      await catalogue.refresh();

      expect(catalogue.designs.any((d) => d.designId == 'design_x'), isTrue);
    });

    test('deactivated products are hidden from customers', () async {
      final staticId = ProductCatalog.staticProducts.first.id;
      final repo = FakeCatalogueRepository()
        ..products.add(ProductCatalog.staticProducts.first
            .copyWith(availability: false));
      final catalogue = CustomerCatalogue(repository: repo);
      await catalogue.refresh();

      expect(catalogue.products.any((p) => p.id == staticId), isFalse);
      expect(catalogue.products.length,
          ProductCatalog.staticProducts.length - 1);
    });

    test('deactivated designs are hidden from customers', () async {
      final staticId = ProductCatalog.staticDesigns.first.designId;
      final repo = FakeCatalogueRepository()
        ..designs.add(ProductCatalog.staticDesigns.first
            .copyWith(availability: false));
      final catalogue = CustomerCatalogue(repository: repo);
      await catalogue.refresh();

      expect(catalogue.designs.any((d) => d.designId == staticId), isFalse);
    });

    test('a failed refresh keeps the last known good catalogue', () async {
      final staticId = ProductCatalog.staticProducts.first.id;
      final repo = FakeCatalogueRepository()
        ..products.add(ProductCatalog.staticProducts.first
            .copyWith(basePrice: 777));
      final catalogue = CustomerCatalogue(repository: repo);

      await catalogue.refresh();
      expect(catalogue.products.firstWhere((p) => p.id == staticId).basePrice,
          777);

      repo.failProductsFetch = true;
      repo.failDesignsFetch = true;
      await catalogue.refresh();

      expect(catalogue.products.firstWhere((p) => p.id == staticId).basePrice,
          777);
      expect(catalogue.products.length, ProductCatalog.staticProducts.length);
    });

    test('products/designs are unmodifiable', () {
      final catalogue = CustomerCatalogue(repository: null);
      expect(() => catalogue.products.add(_sampleBaseProduct()), throwsUnsupportedError);
      expect(() => catalogue.designs.add(_sampleRemoteDesign()), throwsUnsupportedError);
    });
  });

  group('ProductCatalog serves the merged catalogue', () {
    test('search finds a remote-only product', () {
      final newDesign = _sampleDesignProduct();
      CustomerCatalogue.instance.debugApplyForTesting(
        [...ProductCatalog.staticProducts, newDesign],
        [
          ...ProductCatalog.staticDesigns,
          Design.fromProduct(newDesign),
        ],
      );

      expect(ProductCatalog.productById('brand_new_design'), isNotNull);
      expect(
        ProductCatalog.search('Brand New Saree Design')
            .any((p) => p.id == 'brand_new_design'),
        isTrue,
      );
    });

    test('category filtering reflects a remote price override', () {
      final override = ProductCatalog.staticProducts.first
          .copyWith(name: 'Renamed Saree', basePrice: 999);
      CustomerCatalogue.instance.debugApplyForTesting(
        [
          for (final p in ProductCatalog.staticProducts)
            p.id == override.id ? override : p,
        ],
        ProductCatalog.staticDesigns,
      );

      final saree =
          ProductCatalog.productsForCategory('Sarees').firstWhere((p) => p.id == override.id);
      expect(saree.basePrice, 999);
      expect(saree.name, 'Renamed Saree');
    });

    test('search excludes a deactivated static product and featured drops it',
        () {
      final removedId = ProductCatalog.staticProducts.first.id;
      CustomerCatalogue.instance.debugApplyForTesting(
        ProductCatalog.staticProducts
            .where((p) => p.id != removedId)
            .toList(),
        ProductCatalog.staticDesigns,
      );

      expect(ProductCatalog.productById(removedId), isNull);
      expect(
        ProductCatalog.search('Elegant Silk Saree')
            .any((p) => p.id == removedId),
        isFalse,
      );
      expect(ProductCatalog.featured().any((p) => p.id == removedId), isFalse);
    });

    test('derived lists (baseProducts, designs) follow the merged catalogue',
        () {
      final newBase = _sampleBaseProduct(id: 'base_new');
      CustomerCatalogue.instance.debugApplyForTesting(
        [...ProductCatalog.staticProducts, newBase],
        ProductCatalog.staticDesigns,
      );

      expect(
          ProductCatalog.baseProducts.any((p) => p.id == 'base_new'), isTrue);
    });

    test('designs getter surfaces a renamed remote override', () {
      final override = ProductCatalog.staticProducts.first.copyWith(
        name: 'Renamed Saree Design',
      );
      CustomerCatalogue.instance.debugApplyForTesting(
        [
          for (final p in ProductCatalog.staticProducts)
            p.id == override.id ? override : p,
        ],
        ProductCatalog.staticDesigns,
      );

      final design = ProductCatalog.designs.firstWhere((d) => d.designId == override.id);
      expect(design.name, 'Renamed Saree Design');
    });
  });
}
