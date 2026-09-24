import 'package:cloud_firestore/cloud_firestore.dart';

import '../../frontend/models/design.dart';
import '../../frontend/models/product.dart';
import '../../frontend/models/product_variant.dart';

/// Data source for admin-managed catalogue records.
///
/// The existing customer catalogue is a static, code-based list
/// (`ProductCatalog.products`). Admin changes are deliberately NOT migrated
/// into a full Firestore mirror of that 1200+ record list. Instead admin edits
/// are stored as override documents in `products/{productId}` and
/// `designs/{designId}`, and the admin screens render a *merged* view:
///
///   static catalogue (baseline)  +  Firestore overrides (admin changes)
///
/// This keeps the customer-facing catalogue completely untouched (customers
/// keep reading the existing static source), while giving admins a real,
/// persistent create/update/delete workflow that survives app restarts and is
/// shared across devices.
///
/// Deletion is SOFT: a product/design is deactivated (`availability = false`)
/// rather than physically removed, so historical order records that reference
/// it (orders store their own snapshot) are never broken.
abstract class CatalogueRepository {
  /// All admin-managed products (Firestore overrides). Empty when none exist.
  Future<List<Product>> fetchProducts();

  /// All admin-managed designs (Firestore overrides). Empty when none exist.
  Future<List<Design>> fetchDesigns();

  /// Create a brand new product (must carry a fresh id).
  Future<void> createProduct(Product product);

  /// Update an existing product (by id).
  Future<void> updateProduct(Product product);

  /// Hide a product from the storefront without deleting its history.
  Future<void> deactivateProduct(Product product);

  /// Create a brand new design (must carry a fresh id).
  Future<void> createDesign(Design design);

  /// Update an existing design (by designId).
  Future<void> updateDesign(Design design);

  /// Hide a design from the storefront without deleting its history.
  Future<void> deactivateDesign(Design design);
}

/// Firestore-backed [CatalogueRepository].
///
/// Security: every method writes only to the `products` / `designs`
/// collections, whose security rules restrict reads and writes to admins
/// (see firestore.rules). No secrets or API keys exist in client code.
class CatalogueService implements CatalogueRepository {
  final FirebaseFirestore _db;

  CatalogueService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  CollectionReference<Map<String, dynamic>> get _designs =>
      _db.collection('designs');

  @override
  Future<List<Product>> fetchProducts() async {
    try {
      final snapshot = await _products.get();
      return snapshot.docs
          .map((doc) => productFromMap(doc.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<Design>> fetchDesigns() async {
    try {
      final snapshot = await _designs.get();
      return snapshot.docs
          .map((doc) => designFromMap(doc.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> createProduct(Product product) async {
    await _products.doc(product.id).set(productToMap(product));
  }

  @override
  Future<void> updateProduct(Product product) async {
    await _products.doc(product.id).set(productToMap(product));
  }

  @override
  Future<void> deactivateProduct(Product product) async {
    await _products
        .doc(product.id)
        .set(productToMap(product.copyWith(availability: false)));
  }

  @override
  Future<void> createDesign(Design design) async {
    await _designs.doc(design.designId).set(designToMap(design));
  }

  @override
  Future<void> updateDesign(Design design) async {
    await _designs.doc(design.designId).set(designToMap(design));
  }

  @override
  Future<void> deactivateDesign(Design design) async {
    await _designs
        .doc(design.designId)
        .set(designToMap(design.copyWith(availability: false)));
  }

  // ── Serialization ───────────────────────────────────────────────────────
  // Kept as pure static helpers (no Firestore dependency) so they are easy to
  // unit test and reusable from any future sync/storage layer.

  static Map<String, dynamic> productToMap(Product p) => {
        'id': p.id,
        'name': p.name,
        'category': p.category,
        'subcategory': p.subcategory,
        'productType': p.productType,
        'description': p.description,
        'basePrice': p.basePrice,
        'imagePath': p.imagePath,
        'availableFonts': p.availableFonts,
        'availableSizes': p.availableSizes,
        'tags': p.tags,
        'variants': p.variants
            .map((v) => {
                  'label': v.label,
                  'isColor': v.isColor,
                  'colorValue': v.colorValue,
                })
            .toList(),
        'availability': p.availability,
        'customizableOptions': p.customizableOptions,
        'designGallery': p.designGallery,
        'compatibleProductIds': p.compatibleProductIds,
        'compatibleCategories': p.compatibleCategories,
        'material': p.material,
        'measurements': p.measurements
            .map((m) => {'label': m.key, 'value': m.value})
            .toList(),
        'supportedPrintPositions': p.supportedPrintPositions,
        'designType': p.designType,
        'isTrending': p.isTrending,
        'keywords': p.keywords,
        'templateType': p.templateType,
      };

  static Product productFromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        category: map['category'] as String? ?? '',
        subcategory: map['subcategory'] as String? ?? '',
        productType: map['productType'] as String? ?? 'base',
        description: map['description'] as String? ?? '',
        basePrice: (map['basePrice'] as num?)?.toDouble() ?? 0,
        imagePath: map['imagePath'] as String? ?? '',
        availableFonts: _stringList(map['availableFonts']),
        availableSizes: _stringList(map['availableSizes']),
        tags: _stringList(map['tags']),
        variants: ((map['variants'] as List<dynamic>?) ?? [])
            .map((v) {
              final m = Map<String, dynamic>.from(v as Map);
              return ProductVariant(
                label: m['label'] as String? ?? '',
                isColor: m['isColor'] as bool? ?? false,
                colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF607D8B,
              );
            })
            .toList(),
        availability: map['availability'] as bool? ?? true,
        customizableOptions: _stringList(map['customizableOptions']),
        designGallery: _stringList(map['designGallery']),
        compatibleProductIds: _stringList(map['compatibleProductIds']),
        compatibleCategories: _stringList(map['compatibleCategories']),
        material: map['material'] as String?,
        measurements: ((map['measurements'] as List<dynamic>?) ?? [])
            .map((m) {
              final e = Map<String, dynamic>.from(m as Map);
              return MapEntry<String, String>(
                '${e['label']}',
                '${e['value']}',
              );
            })
            .toList(),
        supportedPrintPositions: _stringList(map['supportedPrintPositions']),
        designType: map['designType'] as String? ?? '',
        isTrending: map['isTrending'] as bool? ?? false,
        keywords: _stringList(map['keywords']),
        templateType: map['templateType'] as String? ?? '',
      );

  static Map<String, dynamic> designToMap(Design d) => {
        'designId': d.designId,
        'name': d.name,
        'imagePath': d.imagePath,
        'category': d.category,
        'tags': d.tags,
        'description': d.description,
        'availability': d.availability,
        'compatibleProductIds': d.compatibleProductIds,
        'compatibleCategories': d.compatibleCategories,
        'supportedPrintPositions': d.supportedPrintPositions,
        'designType': d.designType,
        'isTrending': d.isTrending,
        'keywords': d.keywords,
        'templateType': d.templateType,
        'supportsCustomization': d.supportsCustomization,
        'supportsUpload': d.supportsUpload,
        'basePrice': d.basePrice,
      };

  static Design designFromMap(Map<String, dynamic> map) => Design(
        designId: map['designId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        imagePath: map['imagePath'] as String? ?? '',
        category: map['category'] as String? ?? '',
        tags: _stringList(map['tags']),
        description: map['description'] as String?,
        availability: map['availability'] as bool? ?? true,
        compatibleProductIds: _stringList(map['compatibleProductIds']),
        compatibleCategories: _stringList(map['compatibleCategories']),
        supportedPrintPositions: _stringList(map['supportedPrintPositions']),
        designType: map['designType'] as String? ?? '',
        isTrending: map['isTrending'] as bool? ?? false,
        keywords: _stringList(map['keywords']),
        templateType: map['templateType'] as String? ?? '',
        supportsCustomization: map['supportsCustomization'] as bool? ?? true,
        supportsUpload: map['supportsUpload'] as bool? ?? true,
        basePrice: (map['basePrice'] as num?)?.toDouble() ?? 0,
      );

  static List<String> _stringList(dynamic value) =>
      ((value as List<dynamic>?) ?? const []).map((e) => '$e').toList();

  // ── Merging (static catalogue + admin overrides) ───────────────────────

  /// Merge the static [base] catalogue with the admin-managed [remote]
  /// records. A remote record replaces the static one with the same id; brand
  /// new records are appended. Order of the static catalogue is preserved.
  static List<Product> mergeProducts(
      List<Product> base, List<Product> remote) {
    final byId = <String, Product>{for (final p in base) p.id: p};
    for (final p in remote) {
      byId[p.id] = p;
    }
    return byId.values.toList();
  }

  /// Same merge semantics as [mergeProducts] but for [Design] records.
  static List<Design> mergeDesigns(List<Design> base, List<Design> remote) {
    final byId = <String, Design>{for (final d in base) d.designId: d};
    for (final d in remote) {
      byId[d.designId] = d;
    }
    return byId.values.toList();
  }

  // ── Validation ──────────────────────────────────────────────────────────
  // Shared by the admin add/edit forms so validation is testable in one place.

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  /// Rejects values longer than [max] characters so oversized strings never
  /// reach Firestore. Pass through validation for empty/optional fields.
  static String? maxLength(String? value, String label, int max) {
    final v = value?.trim() ?? '';
    if (v.length > max) return '$label must be $max characters or fewer';
    return null;
  }

  static String? validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Price is required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return 'Enter a valid price (0 or more)';
    }
    if (parsed > 1000000) {
      return 'Enter a price of ₹10,00,000 or less';
    }
    return null;
  }

  /// Basic image check: non-empty, and if it looks like a bundled asset path
  /// it must start with the app's asset prefix.
  static String? validateImage(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Image is required';
    if (v.length > 2048) return 'Image reference is too long';
    final isNetwork = v.startsWith('http://') || v.startsWith('https://');
    final isBundled = v.startsWith('assets/');
    if (!isNetwork && !isBundled) {
      return 'Use a bundled asset path (assets/…) or an http(s) URL';
    }
    return null;
  }

  static String? validateCategory(String? value) =>
      value == null || value.isEmpty ? 'Select a category' : null;
}
