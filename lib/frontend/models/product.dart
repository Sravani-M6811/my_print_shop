import 'product_variant.dart';

class Product {
  final String id;
  final String name;
  final String category;

  /// Named section/row this product belongs to within its category catalogue
  /// (e.g. Sarees -> "Silk Plain Sarees" | "Cotton Sarees" | "Pattu Sarees").
  /// Empty means the product isn't grouped into a sub-section. This drives the
  /// sectioned category catalogue screens data-driven, with no per-category UI
  /// code.
  final String subcategory;

  /// 'base' marks a plain product you print ON (e.g. "Plain Saree").
  /// 'design' (default) marks a print design you put ON a product.
  final String productType;
  final String description;
  final double basePrice;
  final String imagePath;
  final List<String> availableFonts;
  final List<String> availableSizes;

  /// Free-text search keywords (e.g. ['wedding', 'floral', 'peacock']).
  /// Extending a record for search is optional but helps surface designs that
  /// don't match on name/category alone.
  final List<String> tags;

  /// Colours / variants a customer can pick for a base/plain product before
  /// choosing a design. Empty (the default) for ordinary design records.
  /// See [ProductVariant].
  final List<ProductVariant> variants;

  /// Whether this product is currently available to order. Unavailable records
  /// are hidden from galleries and detail lists.
  final bool availability;

  /// The customisation tools a customer can apply to this product (e.g.
  /// "Custom Text", "Photo / Logo"). Purely descriptive/drives the UI; kept
  /// data-driven so new customisation capabilities need no code change.
  final List<String> customizableOptions;

  /// Design IDs available for this (base) product. A base product's design
  /// gallery is resolved from the designs whose id appears here; for legacy
  /// records this is derived from the category when empty.
  final List<String> designGallery;

  /// Which plain/base product IDs this design is compatible with (for design
  /// records only). An empty list means compatibility is derived from
  /// [compatibleCategories].
  final List<String> compatibleProductIds;

  /// Which category names this design can be applied to (for design records
  /// only). When [compatibleProductIds] is empty, this list is used to filter
  /// compatible plain products.
  final List<String> compatibleCategories;

  /// Optional primary material/fabric of the product (e.g. '100% Cotton',
  /// 'Silk', 'Ceramic'). Data-driven so it renders on details/cart/order and
  /// stays editable from the catalogue without UI changes.
  final String? material;

  /// Optional product-specific measurements / key-value specs (e.g. 'Length:
  /// 5.5 m', 'Capacity: 330ml', 'Width: 24in'). Shown, data-driven, on the
  /// details screen instead of hard-coded per-category strings.
  final List<MapEntry<String, String>> measurements;

  /// Supported print positions for this product/design (e.g. 'Front', 'Back',
  /// 'Body', 'Pallu'). Drives the print-position picker on the customize
  /// screen; an empty list means the default ('Front') is used.
  final List<String> supportedPrintPositions;

  /// The design category/type for a reusable design record, e.g. 'Lace Border',
  /// 'Painting', 'Trending Print', 'Dialogue', 'Nature', 'Anime', 'Devotional',
  /// 'Sports', 'Jersey', 'Sticker', 'Template'. Empty for plain/base and
  /// ready-made products and for legacy design records. Lets the gallery group
  /// a category's designs into meaningful sub-sections without per-category UI.
  final String designType;

  /// Whether this reusable design is part of the "Trending" collection in its
  /// category. Trend records are surfaced in a dedicated trending section.
  final bool isTrending;

  /// Additional free-text search keywords not already captured in [tags] (e.g.
  /// alternative names, popular search terms, trend keywords). Consulted by the
  /// design and product search in addition to name/category/description/tags.
  final List<String> keywords;

  /// For template-driven categories (e.g. Cardboard) the kind of template this
  /// record represents, e.g. 'Invitation', 'Event', 'School', 'Business',
  /// 'Promotional', 'Celebration', 'Decorative', 'Blank'. Empty when not a
  /// template. The chosen template is passed into the customization stage.
  final String templateType;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.basePrice,
    required this.imagePath,
    this.subcategory = '',
    this.productType = 'design',
    this.availableFonts = const ['Sans-Serif', 'Serif', 'Monospace', 'Cursive'],
    this.availableSizes = const [],
    this.tags = const [],
    this.variants = const [],
    this.availability = true,
    this.customizableOptions = const [],
    this.designGallery = const [],
    this.compatibleProductIds = const [],
    this.compatibleCategories = const [],
    this.material,
    this.measurements = const [],
    this.supportedPrintPositions = const [],
    this.designType = '',
    this.isTrending = false,
    this.keywords = const [],
    this.templateType = '',
  });

  /// True when this is a plain/base product (something you print ON).
  bool get isBase => productType == 'base';

  /// True when this is a reusable print design (the complement of [isBase]).
  bool get isDesign => productType == 'design';

  /// True when this is an already-printed/ready-made product that the customer
  /// can buy directly without choosing a design.
  bool get isReadyMade => productType == 'readyMade';

  /// True when the product may currently be ordered.
  bool get isAvailable => availability;

  /// The colour options offered for this product (from its real-colour
  /// variants). Non-colour choices (e.g. poster finishes) are excluded, so UI
  /// that only wants the swatches can read these directly.
  List<String> get availableColors =>
      variants.where((v) => v.isColor).map((v) => v.label).toList();

  /// The design IDs available for this base product. Legacy/base records with
  /// no explicit [designGallery] still expose a category-scoped gallery by
  /// falling back to that category's designs (resolved by the catalog).
  List<String> get designIds =>
      designGallery.isNotEmpty ? designGallery : const [];

  /// A copy of this product with any of the given fields replaced.
  Product copyWith({
    String? name,
    String? category,
    String? subcategory,
    String? productType,
    String? description,
    double? basePrice,
    String? imagePath,
    List<String>? availableFonts,
    List<String>? availableSizes,
    List<String>? tags,
    List<ProductVariant>? variants,
    bool? availability,
    List<String>? customizableOptions,
    List<String>? designGallery,
    List<String>? compatibleProductIds,
    List<String>? compatibleCategories,
    String? material,
    List<MapEntry<String, String>>? measurements,
    List<String>? supportedPrintPositions,
    String? designType,
    bool? isTrending,
    List<String>? keywords,
    String? templateType,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      productType: productType ?? this.productType,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      imagePath: imagePath ?? this.imagePath,
      availableFonts: availableFonts ?? this.availableFonts,
      availableSizes: availableSizes ?? this.availableSizes,
      tags: tags ?? this.tags,
      variants: variants ?? this.variants,
      availability: availability ?? this.availability,
      customizableOptions: customizableOptions ?? this.customizableOptions,
      designGallery: designGallery ?? this.designGallery,
      compatibleProductIds: compatibleProductIds ?? this.compatibleProductIds,
      compatibleCategories: compatibleCategories ?? this.compatibleCategories,
      material: material ?? this.material,
      measurements: measurements ?? this.measurements,
      supportedPrintPositions:
          supportedPrintPositions ?? this.supportedPrintPositions,
      designType: designType ?? this.designType,
      isTrending: isTrending ?? this.isTrending,
      keywords: keywords ?? this.keywords,
      templateType: templateType ?? this.templateType,
    );
  }

  /// True when [query] matches the name, category, description, tags, material,
  /// colours/variants, sizes, subcategory, product type, design type, template
  /// type or extra search keywords (case-insensitive, partial). Matching the
  /// description helps surface designs whose visual attributes (e.g. "floral")
  /// live in the copy rather than the name/category/tags; material/variant/size
  /// matching makes the Home/global search useful beyond the visible cards.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    if (name.toLowerCase().contains(q)) return true;
    if (category.toLowerCase().contains(q)) return true;
    if (description.toLowerCase().contains(q)) return true;
    if (subcategory.toLowerCase().contains(q)) return true;
    if (productType.toLowerCase().contains(q)) return true;
    if (designType.toLowerCase().contains(q)) return true;
    if (templateType.toLowerCase().contains(q)) return true;
    if (material != null && material!.toLowerCase().contains(q)) return true;
    if (tags.any((t) => t.toLowerCase().contains(q))) return true;
    if (keywords.any((t) => t.toLowerCase().contains(q))) return true;
    if (variants.any((v) => v.label.toLowerCase().contains(q))) return true;
    if (availableSizes.any((s) => s.toLowerCase().contains(q))) return true;
    return false;
  }
}
