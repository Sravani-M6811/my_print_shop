import './product.dart';

/// A reusable print design / artwork that can be placed on a plain (base)
/// product, e.g. a floral motif, a border pattern, a birthday greeting.
///
/// This is the dedicated "design" concept in the catalogue. It is distinct
/// from the physical [Product] you print ON: a design holds the artwork
/// identity (name, image, category, tags, availability) while a base product
/// holds the physical option (colors, variants, price). Choosing a base
/// product then browsing its design gallery yields a set of these records.
class Design {
  /// Stable machine identifier, e.g. 'design_floral_saree'.
  final String designId;

  /// Human-facing design name, e.g. 'Golden Floral Motif'.
  final String name;

  /// Path to the design artwork image (a real bundled asset).
  final String imagePath;

  /// Category this design belongs to (one of the catalogue category names).
  final String category;

  /// Searchable keywords/tags for this design (supports design-name search).
  final List<String> tags;

  /// Optional human description of the design.
  final String? description;

  /// Whether the design is currently available for ordering.
  final bool availability;

  /// Which plain/base product IDs this design is compatible with. When empty,
  /// [compatibleCategories] is used instead.
  final List<String> compatibleProductIds;

  /// Which category names this design can be applied to. Used as a fallback
  /// when [compatibleProductIds] is empty.
  final List<String> compatibleCategories;

  /// Supported print positions for this design (e.g. 'Front', 'Back', 'Both',
  /// 'Body', 'Pallu'). An empty list means the caller should use the default.
  final List<String> supportedPrintPositions;

  /// The design category/type (e.g. 'Lace Border', 'Painting', 'Trending
  /// Print', 'Dialogue', 'Nature', 'Anime', 'Template'). Lets the gallery group
  /// designs into meaningful sub-sections and filter by type.
  final String designType;

  /// Whether this design belongs to its category's trending collection.
  final bool isTrending;

  /// Additional search keywords/trend terms beyond [tags].
  final List<String> keywords;

  /// For template-driven categories (e.g. Cardboard) the kind of template
  /// ('Invitation', 'Event', 'School', ...). Empty when not a template.
  final String templateType;

  /// Whether the customer can customize this design (text/photo/colour).
  final bool supportsCustomization;

  /// Whether the customer can upload their own artwork for this design.
  final bool supportsUpload;

  /// The standard selling price (in ₹) charged when this design is customized
  /// onto a plain product. Mirrors the underlying catalogue record's
  /// [Product.basePrice]; 0 means the base product's price applies.
  final double basePrice;

  const Design({
    required this.designId,
    required this.name,
    required this.imagePath,
    required this.category,
    this.tags = const [],
    this.description,
    this.availability = true,
    this.compatibleProductIds = const [],
    this.compatibleCategories = const [],
    this.supportedPrintPositions = const [],
    this.designType = '',
    this.isTrending = false,
    this.keywords = const [],
    this.templateType = '',
    this.supportsCustomization = true,
    this.supportsUpload = true,
    this.basePrice = 0,
  });

  /// Interpret an existing catalogue [Product] design record as a [Design].
  ///
  /// The data layer keeps design records as [Product]s with
  /// `productType == 'design'` (so legacy search/listing code and tests stay
  /// intact), while the gallery/UI layer can consult them as first-class
  /// [Design] values. This is a cheap view over the same record — no
  /// duplicated data set, so the two models can never drift apart.
  factory Design.fromProduct(Product product) => Design(
        designId: product.id,
        name: product.name,
        imagePath: product.imagePath,
        category: product.category,
        tags: product.tags,
        description: product.description,
        availability: product.availability,
        compatibleProductIds: product.compatibleProductIds,
        compatibleCategories: product.compatibleCategories,
        supportedPrintPositions: product.supportedPrintPositions,
        designType: product.designType,
        isTrending: product.isTrending,
        keywords: product.keywords,
        templateType: product.templateType,
        basePrice: product.basePrice,
      );

  /// A copy of this design with any of the given fields replaced.
  Design copyWith({
    String? name,
    String? imagePath,
    String? category,
    List<String>? tags,
    String? description,
    bool? availability,
    List<String>? compatibleProductIds,
    List<String>? compatibleCategories,
    List<String>? supportedPrintPositions,
    String? designType,
    bool? isTrending,
    List<String>? keywords,
    String? templateType,
    bool? supportsCustomization,
    bool? supportsUpload,
    double? basePrice,
  }) {
    return Design(
      designId: designId,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      description: description ?? this.description,
      availability: availability ?? this.availability,
      compatibleProductIds: compatibleProductIds ?? this.compatibleProductIds,
      compatibleCategories: compatibleCategories ?? this.compatibleCategories,
      supportedPrintPositions:
          supportedPrintPositions ?? this.supportedPrintPositions,
      designType: designType ?? this.designType,
      isTrending: isTrending ?? this.isTrending,
      keywords: keywords ?? this.keywords,
      templateType: templateType ?? this.templateType,
      supportsCustomization: supportsCustomization ?? this.supportsCustomization,
      supportsUpload: supportsUpload ?? this.supportsUpload,
      basePrice: basePrice ?? this.basePrice,
    );
  }

  /// True when [query] matches the design name, category, description, tags,
  /// design type, template type or extra keywords (case-insensitive, partial).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    if (name.toLowerCase().contains(q)) return true;
    if (category.toLowerCase().contains(q)) return true;
    if (designType.toLowerCase().contains(q)) return true;
    if (templateType.toLowerCase().contains(q)) return true;
    if (description?.toLowerCase().contains(q) ?? false) return true;
    if (tags.any((t) => t.toLowerCase().contains(q))) return true;
    return keywords.any((t) => t.toLowerCase().contains(q));
  }

  /// Whether this design is compatible with the given [productId] and
  /// [productCategory]. Checks [compatibleProductIds] first, then falls back
  /// to [compatibleCategories], then to the design's own [category].
  bool isCompatibleWith(String productId, String productCategory) {
    if (compatibleProductIds.contains(productId)) return true;
    if (compatibleCategories.contains(productCategory)) return true;
    if (compatibleProductIds.isEmpty && compatibleCategories.isEmpty) {
      return category == productCategory;
    }
    return false;
  }
}
