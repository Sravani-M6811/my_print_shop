/// Metadata for a single catalogue image in MY PRINT SHOP.
///
/// This is the data layer that lets the store scale to 10,000+ catalogue
/// images WITHOUT bloating widget code or shipping gigabytes of bundled
/// assets: every image (bundled asset or remote URL) is described by one
/// [CatalogueImageInfo] row, and grids/lists render from the registry through
/// lazy loading. Any new image is simply a new registered row — no per-image
/// UI code is ever required.
class CatalogueImageSource {
  /// Bundled with the app (rendered via `Image.asset`).
  static const String bundled = 'bundled';

  /// Served over http(s) — a live stock/design URL or CDN (rendered via
  /// `Image.network`). This is where bulk curated images (e.g. stock photo
  /// feeds) live so the 10k backlog never has to inflate the app size.
  static const String remote = 'remote';

  /// Customer/admin-uploaded (moved to Firebase Storage via the client).
  static const String uploaded = 'uploaded';

  const CatalogueImageSource._();
}

class CatalogueImageType {
  /// A plain/base product image ("what do I print ON").
  static const String product = 'product';

  /// A reusable print design image.
  static const String design = 'design';

  /// A ready-made / already-printed product image.
  static const String readyMade = 'readyMade';

  const CatalogueImageType._();
}

class CatalogueImageStatus {
  static const String active = 'active';
  static const String draft = 'draft';
  static const String inactive = 'inactive';

  const CatalogueImageStatus._();
}

class CatalogueImageInfo {
  /// Stable machine identifier, e.g. 'img_000123'.
  final String id;

  /// `assets/images/...` asset path or an http(s) URL.
  final String path;

  /// Top-level catalogue category (Sarees, T-Shirts, Mugs, …).
  final String categoryId;

  /// Named sub-section / row within the category when known ('Silk Plain
  /// Sarees', null when the image belongs to no row).
  final String? subcategoryId;

  /// One of [CatalogueImageType].
  final String type;

  /// One of [CatalogueImageSource].
  final String source;

  /// Searchable keywords/tags for this image (product tags + keywords).
  final List<String> tags;

  /// One of [CatalogueImageStatus]. Inactive rows are excluded from display.
  final String status;

  /// When the image entered the registry.
  final DateTime? addedAt;

  const CatalogueImageInfo({
    required this.id,
    required this.path,
    required this.categoryId,
    this.subcategoryId,
    this.type = CatalogueImageType.product,
    this.source = CatalogueImageSource.bundled,
    this.tags = const [],
    this.status = CatalogueImageStatus.active,
    this.addedAt,
  });

  bool get isRemote =>
      path.startsWith('http://') || path.startsWith('https://');

  bool get isActive => status == CatalogueImageStatus.active;

  /// True when [query] matches the id, path, category, subcategory, type or
  /// tags (case-insensitive, partial).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    if (id.toLowerCase().contains(q)) return true;
    if (path.toLowerCase().contains(q)) return true;
    if (categoryId.toLowerCase().contains(q)) return true;
    if (subcategoryId?.toLowerCase().contains(q) ?? false) return true;
    if (type.toLowerCase().contains(q)) return true;
    return tags.any((t) => t.toLowerCase().contains(q));
  }

  @override
  String toString() => 'CatalogueImageInfo($id, $categoryId, $type, $path)';
}