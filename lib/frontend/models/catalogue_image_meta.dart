import './product.dart';

/// Searchable metadata describing a single catalogue image.
///
/// The store's image-heavy future (10 000+ images) is served by a data-driven
/// registry rather than hard-coded UI: every product/design imagePath is
/// modelled as a [CatalogueImageMeta] record that can be paged, filtered and
/// searched without materializing the full catalogue. Products and designs both
/// flatten into this one record type, so admin screens and paginated galleries
/// share a single source of truth.
class CatalogueImageMeta {
  /// Stable image identifier, e.g. 'base_saree#0'. One record per image
  /// (design galleries contribute one record per artwork image).
  final String imageId;

  /// Local asset path or network URL of the rendered artwork.
  final String imagePath;

  /// Owning category.
  final String category;

  /// Owning category's stable id if known ('' otherwise).
  final String categoryId;

  /// Named sub-section the record belongs to ('' when ungrouped).
  final String subcategory;

  /// Owning sub-category's stable id if known ('' otherwise).
  final String subcategoryId;

  /// 'base' | 'design' | 'readyMade' — mirrors [Product.productType].
  final String type;

  /// Original catalogue record id ('', e.g. for a derivative artwork image).
  final String productId;

  /// Design id when this image belongs to a reusable [Design] ('' otherwise).
  final String designId;

  /// Design type for design/ready-made records ('' otherwise).
  final String designType;

  /// Primary material/fabric (e.g. '100% Cotton'); '' when not specified.
  final String material;

  /// Size label (e.g. 'M', 'A3', '330ml'); '' when not specified.
  final String size;

  /// Colour/variant label (canonical first colour); '' when no colours.
  final String color;

  /// Selling price in ₹ for this image's record.
  final double price;

  /// Whether the record is currently orderable.
  final bool availability;

  /// Whether this image participates in the trending rail.
  final bool isTrending;

  /// Searchable tags/keywords (name, category, tags, keywords).
  final List<String> tags;

  /// Compatibility for design records (product ids / category names);
  /// empty for base/plain products.
  final List<String> compatibleProductIds;
  final List<String> compatibleCategories;

  /// Free-form metadata carried for the record this image belongs to.
  final Map<String, dynamic> metadata;

  /// Content-hash timestamp of first registration; add-only via the registry.
  final DateTime createdAt;
  final DateTime updatedAt;

  const CatalogueImageMeta({
    required this.imageId,
    required this.imagePath,
    required this.category,
    this.categoryId = '',
    this.subcategory = '',
    this.subcategoryId = '',
    this.type = 'design',
    this.productId = '',
    this.designId = '',
    this.designType = '',
    this.material = '',
    this.size = '',
    this.color = '',
    this.price = 0,
    this.availability = true,
    this.isTrending = false,
    this.tags = const [],
    this.compatibleProductIds = const [],
    this.compatibleCategories = const [],
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Shorthand: build a metadata record directly from a catalogue [Product].
  factory CatalogueImageMeta.fromProduct(Product p) {
    final color = p.availableColors.isEmpty ? '' : p.availableColors.first;
    return CatalogueImageMeta(
      imageId: '${p.id}:main',
      imagePath: p.imagePath,
      category: p.category,
      subcategory: p.subcategory,
      type: p.productType,
      productId: p.id,
      designId: p.isBase ? '' : p.id,
      designType: p.designType,
      material: p.material ?? '',
      size: p.availableSizes.isEmpty ? '' : p.availableSizes.first,
      color: color,
      price: p.basePrice,
      availability: p.availability,
      isTrending: p.isTrending,
      tags: [
        p.name,
        p.category,
        p.subcategory,
        p.designType,
        p.templateType,
        ...p.tags,
        ...p.keywords,
      ],
      compatibleProductIds: p.compatibleProductIds,
      compatibleCategories: p.compatibleCategories,
      metadata: {
        'name': p.name,
        'description': p.description,
        'sizes': p.availableSizes,
        'colors': p.availableColors,
      },
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  }

  /// True when [query] matches any tag (case-insensitive, partial).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    return tags.any((t) => t.toLowerCase().contains(q));
  }

  CatalogueImageMeta copyWith({
    String? subcategoryId,
    Map<String, dynamic>? metadata,
    DateTime? updatedAt,
  }) {
    return CatalogueImageMeta(
      imageId: imageId,
      imagePath: imagePath,
      category: category,
      categoryId: categoryId,
      subcategory: subcategory,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      type: type,
      productId: productId,
      designId: designId,
      designType: designType,
      material: material,
      size: size,
      color: color,
      price: price,
      availability: availability,
      isTrending: isTrending,
      tags: tags,
      compatibleProductIds: compatibleProductIds,
      compatibleCategories: compatibleCategories,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
