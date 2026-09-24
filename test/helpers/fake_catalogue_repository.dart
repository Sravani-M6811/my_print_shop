import 'package:my_print_shop/frontend/models/design.dart';
import 'package:my_print_shop/frontend/models/product.dart';
import 'package:my_print_shop/admin/services/catalogue_service.dart';

/// In-memory [CatalogueRepository] for widget tests.
///
/// Mirrors the soft-delete semantics of the real Firestore service
/// (deactivation stores an `availability = false` copy) so the UI behaves the
/// same in tests as against a live backend.
class FakeCatalogueRepository implements CatalogueRepository {
  final List<Product> products = [];
  final List<Design> designs = [];

  bool failProductsFetch = false;
  bool failDesignsFetch = false;
  bool failWrites = false;

  final List<String> productCreatedIds = [];
  final List<String> productUpdatedIds = [];
  final List<String> productDeactivatedIds = [];

  final List<String> designCreatedIds = [];
  final List<String> designUpdatedIds = [];
  final List<String> designDeactivatedIds = [];

  @override
  Future<List<Product>> fetchProducts() async {
    if (failProductsFetch) throw Exception('products fetch failed');
    return List.of(products);
  }

  @override
  Future<List<Design>> fetchDesigns() async {
    if (failDesignsFetch) throw Exception('designs fetch failed');
    return List.of(designs);
  }

  @override
  Future<void> createProduct(Product product) async {
    if (failWrites) throw Exception('write failed');
    productCreatedIds.add(product.id);
    products.removeWhere((p) => p.id == product.id);
    products.add(product);
  }

  @override
  Future<void> updateProduct(Product product) async {
    if (failWrites) throw Exception('write failed');
    productUpdatedIds.add(product.id);
    products.removeWhere((p) => p.id == product.id);
    products.add(product);
  }

  @override
  Future<void> deactivateProduct(Product product) async {
    if (failWrites) throw Exception('write failed');
    productDeactivatedIds.add(product.id);
    final copy = product.copyWith(availability: false);
    products.removeWhere((p) => p.id == product.id);
    products.add(copy);
  }

  @override
  Future<void> createDesign(Design design) async {
    if (failWrites) throw Exception('write failed');
    designCreatedIds.add(design.designId);
    designs.removeWhere((d) => d.designId == design.designId);
    designs.add(design);
  }

  @override
  Future<void> updateDesign(Design design) async {
    if (failWrites) throw Exception('write failed');
    designUpdatedIds.add(design.designId);
    designs.removeWhere((d) => d.designId == design.designId);
    designs.add(design);
  }

  @override
  Future<void> deactivateDesign(Design design) async {
    if (failWrites) throw Exception('write failed');
    designDeactivatedIds.add(design.designId);
    final copy = design.copyWith(availability: false);
    designs.removeWhere((d) => d.designId == design.designId);
    designs.add(copy);
  }
}
