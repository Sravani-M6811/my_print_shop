import '../../frontend/data/product_catalog.dart';
import '../../frontend/models/catalogue_image_meta.dart';
import '../../frontend/models/product.dart';
import '../../frontend/models/product_subcategory.dart';

/// Data-driven registry for every catalogue image.
///
/// The 10k-image plan: products and designs are flattened into
/// [CatalogueImageMeta] records and served in pages (default 48) through
/// [page]/[count] instead of materializing the whole catalogue for every
/// screen. Category/subcategory ids are resolved by reverse-mapping the
/// record's `subcategory` label onto the [ProductCatalog] sub-category aliases.
class ImageCatalogueRegistry {
  ImageCatalogueRegistry._();

  static final ImageCatalogueRegistry instance = ImageCatalogueRegistry._();

  List<CatalogueImageMeta>? _index;

  /// The full derived metadata index (built lazily from the catalogue).
  List<CatalogueImageMeta> get all {
    final existing = _index;
    if (existing != null) return existing;
    final built = _buildIndex();
    _index = built;
    return built;
  }

  /// Forces a rebuild on the next read (used when the catalogue changes or new
  /// images are registered).
  void refresh() => _index = null;

  List<CatalogueImageMeta> _buildIndex() {
    final result = <CatalogueImageMeta>[];
    for (final p in ProductCatalog.products) {
      if (!p.isAvailable) continue;
      result.add(_metaFor(p));
      // Design galleries on base products represent additional artwork images;
      // register each referenced record too (deduplicated by id).
      for (final id in p.designGallery) {
        final design = ProductCatalog.productById(id);
        if (design == null || design.isBase) continue;
        result.add(CatalogueImageMeta.fromProduct(design));
      }
    }
    // Deduplicate by imageId (order preserved).
    final seen = <String>{};
    return result.where((m) => seen.add(m.imageId)).toList();
  }

  static CatalogueImageMeta _metaFor(Product p) {
    final meta = CatalogueImageMeta.fromProduct(p);
    final ids = _resolveIds(p);
    return meta.copyWith(
      subcategoryId: ids.$1,
      updatedAt: meta.updatedAt,
    );
  }

  /// Resolves (categoryId, subcategoryId) for a product from the descriptor
  /// data, so metadata records never drift from the displayed sub-categories.
  static (String, String) _resolveIds(Product p) {
    for (final descriptor in ProductCatalog.categoryDescriptors) {
      if (descriptor.name != p.category) continue;
      for (final sub in descriptor.subcategories) {
        if (sub.aliases.contains(p.subcategory)) {
          return (descriptor.id, sub.id);
        }
      }
      // Category id is still known even when no sub-category alias matches.
      return (descriptor.id, '');
    }
    return ('', '');
  }

  /// Total image count after applying the given filters.
  int count({
    String? category,
    String? subcategoryId,
    String? type,
    String? query,
  }) {
    return _applyFilters(category: category, subcategoryId: subcategoryId, type: type, query: query).length;
  }

  /// One page (1-based) of image metadata. Filters are independent and combined
  /// with AND; [query] matches any tag/name keyword.
  List<CatalogueImageMeta> page({
    int page = 1,
    int pageSize = 48,
    String? category,
    String? subcategoryId,
    String? type,
    String? query,
  }) {
    final filtered = _applyFilters(
      category: category,
      subcategoryId: subcategoryId,
      type: type,
      query: query,
    );
    if (filtered.isEmpty || page < 1 || pageSize < 1) return const [];
    final start = (page - 1) * pageSize;
    if (start >= filtered.length) return const [];
    final end = (start + pageSize) > filtered.length ? filtered.length : start + pageSize;
    return filtered.sublist(start, end);
  }

  List<CatalogueImageMeta> _applyFilters({
    String? category,
    String? subcategoryId,
    String? type,
    String? query,
  }) {
    var result = all;
    if (category != null && category.isNotEmpty) {
      result = result.where((m) => m.category == category).toList();
    }
    if (subcategoryId != null && subcategoryId.isNotEmpty) {
      result = result.where((m) => m.subcategoryId == subcategoryId).toList();
    }
    if (type != null && type.isNotEmpty) {
      result = result.where((m) => m.type == type).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      result = result.where((m) => m.matches(query)).toList();
    }
    return result;
  }

  CatalogueImageMeta? byId(String imageId) {
    for (final m in all) {
      if (m.imageId == imageId) return m;
    }
    return null;
  }

  /// Registers or updates a metadata record (admin edits: availability toggles,
  /// sub-category reassignment). Keeps the index fresh on the next read.
  void upsert(CatalogueImageMeta updated) {
    final existing = _index;
    if (existing == null) return;
    final idx = existing.indexWhere((m) => m.imageId == updated.imageId);
    if (idx >= 0) {
      existing[idx] = updated;
    } else {
      existing.add(updated);
    }
  }

  /// Convenience: the sub-category a metadata record belongs to, or null.
  ProductSubcategory? subcategoryFor(CatalogueImageMeta meta) {
    if (meta.subcategoryId.isEmpty) return null;
    return ProductCatalog.subcategoryById(meta.subcategoryId);
  }
}
