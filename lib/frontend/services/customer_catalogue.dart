import 'package:flutter/foundation.dart';

import '../data/product_catalog.dart';
import '../models/design.dart';
import '../models/product.dart';
import '../../admin/services/catalogue_service.dart';

/// Customer-facing, read-only merged view of the print-shop catalogue.
///
/// The app ships a large static catalogue (`ProductCatalog.staticProducts` /
/// `staticDesigns`) so the store is fully usable offline and the instant the
/// app opens. [CustomerCatalogue] overlays admin-managed Firestore overrides
/// (`products/{productId}` and `designs/{designId}`) on top of that static
/// base:
///
///  * Remote records replace the static record with the same id — including
///    price/name/image edits and admin deactivations.
///  * Remote records with a new id are appended to the static list.
///  * Records marked `availability == false` are hidden from customers.
///  * If Firestore is unreachable (or any fetch fails) the static catalogue is
///    kept untouched — the store never shows a blank page.
///
/// Consumers read [products] / [designs] (unmodifiable). The static
/// `ProductCatalog` getters are wired to this singleton so existing customer
/// screens, search and category helpers all see merged data automatically.
class CustomerCatalogue extends ChangeNotifier {
  /// Creates a catalogue over the [ProductCatalog] static base.
  ///
  /// [repository] is injectable for tests; when omitted the Firestore-backed
  /// [CatalogueService] is constructed lazily on the first successful
  /// [refresh] (so constructing the singleton never touches Firestore and
  /// always falls back to the static catalogue when Firestore is unavailable).
  CustomerCatalogue({CatalogueRepository? repository}) {
    _repository = repository;
    _products = List.of(_staticProducts);
    _designs = List.of(_staticDesigns);
  }

  /// The app-wide catalogue instance that [ProductCatalog] serves to every
  /// customer screen.
  static final CustomerCatalogue instance = CustomerCatalogue();

  CatalogueRepository? _repository;
  CatalogueRepository? _lazyRepository;

  late List<Product> _products;
  late List<Design> _designs;

  bool _isLoading = false;

  static List<Product> get _staticProducts => ProductCatalog.staticProducts;
  static List<Design> get _staticDesigns => ProductCatalog.staticDesigns;

  /// True while a refresh/merge is in flight. The static catalogue remains
  /// visible throughout, so this is only a hint for optional spinners.
  bool get isLoading => _isLoading;

  /// The merged, availability-filtered product catalogue (unmodifiable).
  List<Product> get products => List.unmodifiable(_products);

  /// The merged, availability-filtered design catalogue (unmodifiable).
  List<Design> get designs => List.unmodifiable(_designs);

  /// Fetches admin-managed overrides from Firestore and merges them over the
  /// static base. Safe to call any number of times (idempotent, re-entrancy
  /// guarded); on any failure the current catalogue is left untouched.
  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      final repository = _lazyRepository ??= _repository ?? CatalogueService();
      final remoteDesigns = await repository.fetchDesigns();
      final remoteProducts = await repository.fetchProducts();
      final mergedProducts =
          CatalogueService.mergeProducts(_staticProducts, remoteProducts);
      final mergedDesigns =
          CatalogueService.mergeDesigns(_staticDesigns, remoteDesigns);
      _products = mergedProducts.where((p) => p.availability).toList();
      _designs = mergedDesigns.where((d) => d.availability).toList();
    } catch (_) {
      // Firestore unavailable or transient failure: keep the static catalogue
      // so customers always have something to browse.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Test hook: replaces the visible catalogue contents immediately.
  @visibleForTesting
  void debugApplyForTesting(List<Product> products, List<Design> designs) {
    _products = List.of(products);
    _designs = List.of(designs);
    notifyListeners();
  }

  /// Test hook: restores the pristine static catalogue.
  @visibleForTesting
  void debugResetForTesting() {
    _products = List.of(_staticProducts);
    _designs = List.of(_staticDesigns);
    notifyListeners();
  }
}
