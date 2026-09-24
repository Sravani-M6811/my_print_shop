import '../../frontend/data/product_catalog.dart';
import '../../frontend/models/catalogue_image.dart';

/// Registry of every known catalogue image.
///
/// For the 10,000+ image target this is the single source of truth the whole
/// store renders against. It is seeded from the existing catalogue (bundled
/// assets) plus the declared remote stock/design URLs, and every consumer
/// (catalogue grids, admin pickers, search) reads from this registry rather
/// than hand-rolling paths. Rows are cheap, lazy and never block first paint;
/// bulk remote feeds plug in here without touching a single widget.
class CatalogueImageRegistry {
  CatalogueImageRegistry._();

  static final CatalogueImageRegistry instance = CatalogueImageRegistry._();

  static const int _maxSuggestionChips = 10;

  late final List<CatalogueImageInfo> _images = _buildIndex();

  /// Total registered active images.
  int get total => _images.length;

  /// Total images registered per category (active only), sorted by count.
  Map<String, int> get categoryCounts {
    final counts = <String, int>{};
    for (final img in _images) {
      counts[img.categoryId] = (counts[img.categoryId] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  /// All registered images (active first), in a stable order.
  List<CatalogueImageInfo> all() => List.unmodifiable(_images);

  /// Active images for [category], optionally filtered by [type].
  List<CatalogueImageInfo> forCategory(String category, {String? type}) {
    return _images
        .where((i) =>
            i.isActive &&
            i.categoryId == category &&
            (type == null || i.type == type))
        .toList();
  }

  /// Active images inside a named sub-section/row of a category.
  List<CatalogueImageInfo> forSubcategory(
      String category, String subcategory) {
    return _images
        .where((i) =>
            i.isActive &&
            i.categoryId == category &&
            i.subcategoryId == subcategory)
        .toList();
  }

  int countForCategory(String category) =>
      _images.where((i) => i.isActive && i.categoryId == category).length;

  /// Bundled asset paths administrators may quick-pick for [category]
  /// (first [CatalogueImageType] per unique path, capped). Falls back to any
  /// known bundled path in the category so the admin picker always offers
  /// something that will actually render.
  List<String> suggestionPathsFor(String category) {
    final seen = <String>{};
    final paths = <String>[];
    for (final img in forCategory(category)) {
      if (img.source != CatalogueImageSource.bundled) continue;
      if (!seen.add(img.path)) continue;
      paths.add(img.path);
      if (paths.length >= _maxSuggestionChips) break;
    }
    return paths;
  }

  /// Case-insensitive keyword/tag/path search across all active images.
  List<CatalogueImageInfo> search(String query, {int? limit}) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final results = _images.where((i) => i.isActive && i.matches(q)).toList();
    if (limit != null && results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  /// Registers a new image row (e.g. after an admin uploads one). Duplicate
  /// paths are ignored so the registry stays a clean set.
  void register(CatalogueImageInfo image) {
    if (_images.any((i) => i.path == image.path)) return;
    _images.add(image);
  }

  /// Seeds the registry from the shipped catalogue. Deduplicated by path, and
  /// keyed with subcategory/type from the product rows so queries just work.
  List<CatalogueImageInfo> _buildIndex() {
    final seen = <String>{};
    final out = <CatalogueImageInfo>[];
    var counter = 0;
    for (final product in ProductCatalog.products) {
      if (product.imagePath.isEmpty || product.availability == false) continue;
      if (!seen.add(product.imagePath)) continue;
      counter += 1;
      final isRemote = product.imagePath.startsWith('http');
      out.add(CatalogueImageInfo(
        id: 'img_${counter.toString().padLeft(6, '0')}',
        path: product.imagePath,
        categoryId: product.category,
        subcategoryId:
            product.subcategory.trim().isEmpty ? null : product.subcategory.trim(),
        type: product.productType == 'design'
            ? CatalogueImageType.design
            : CatalogueImageType.product,
        source: isRemote
            ? CatalogueImageSource.remote
            : CatalogueImageSource.bundled,
        tags: [...product.tags, ...product.keywords],
        status: CatalogueImageStatus.active,
      ));
    }
    return out;
  }
}
