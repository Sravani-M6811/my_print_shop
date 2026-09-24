import 'dart:ui';

class CartItem {
  final String id;
  final String title;
  final String category;
  final String customText;
  final String selectedSide;
  final String fontFamily;
  final double price;
  final Color color;
  final String? imagePath;
  final int quantity;

  /// The plain/base product (e.g. "Plain Saree") this item is printed on, if
  /// the item came through the "Start With a Product" flow. Null for items
  /// added directly from a design gallery (keeps all existing items valid).
  final String? baseProductTitle;

  /// The colour/variant label chosen for the base product (e.g. "Red",
  /// "Matte", "Clear"). Null for items added without a base product or from
  /// old stored data, so existing carts/orders deserialize safely.
  final String? selectedVariant;

  /// The name of the selected design/artwork (e.g. "Golden Floral Motif").
  /// Stored alongside the base product so two visually similar products with
  /// different designs remain clearly distinguishable in the cart and order.
  final String? designName;

  /// The stable id of the selected design/artwork, if any.
  final String? designId;

  /// The stable id of the plain/base product this item is printed on, if any.
  /// Distinct from [designId] and preserved so the order can reproduce exactly
  /// what the customer configured.
  final String? baseProductId;

  /// Where on the product the design is printed (e.g. 'Front', 'Back', 'Both',
  /// 'Body', 'Pallu'). Product/category-specific and carried to the order.
  final String? printPosition;

  /// Reference to a customer-uploaded design image (local path or Firebase
  /// Storage URL). Null when the customer picked one of our designs instead.
  final String? uploadedDesignPath;

  /// The size chosen for the base product (e.g. 'L', 'XL'). Null for items
  /// where size does not apply or old stored data. Preserved to the order so
  /// fulfilment knows exactly which variant to print.
  final String? size;

  /// The material/fabric of the base product (e.g. '100% Cotton'). Carried
  /// from the product's data-driven specs so the cart/order repeat it.
  final String? material;

  /// Additional product-specific measurements chosen/applied, as label -> value
  /// pairs (e.g. Length, Width, Capacity). Preserved to the order.
  final List<MapEntry<String, String>> measurements;

  /// Stitching option chosen for Dress Materials, one of `'With Stitching'` or
  /// `'Without Stitching'`. Null when not applicable (other categories) or old
  /// stored data, so existing carts/orders deserialize safely.
  final String? stitching;

  const CartItem({
    required this.id,
    required this.title,
    required this.category,
    required this.customText,
    required this.selectedSide,
    required this.fontFamily,
    required this.price,
    required this.color,
    this.imagePath,
    this.quantity = 1,
    this.baseProductTitle,
    this.selectedVariant,
    this.designName,
    this.designId,
    this.baseProductId,
    this.printPosition,
    this.uploadedDesignPath,
    this.size,
    this.material,
    this.measurements = const [],
    this.stitching,
  });

  /// Total price for this line (per-unit price × quantity).
  double get lineTotal => price * quantity;

  /// Copy, replacing only the provided fields and preserving every other field.
  CartItem copyWith({
    int? quantity,
    String? baseProductTitle,
    String? selectedVariant,
    String? designName,
    String? designId,
    String? baseProductId,
    String? printPosition,
    String? uploadedDesignPath,
    String? size,
    String? material,
    List<MapEntry<String, String>>? measurements,
    String? stitching,
  }) =>
      CartItem(
        id: id,
        title: title,
        category: category,
        customText: customText,
        selectedSide: selectedSide,
        fontFamily: fontFamily,
        price: price,
        color: color,
        imagePath: imagePath,
        quantity: quantity ?? this.quantity,
        baseProductTitle: baseProductTitle ?? this.baseProductTitle,
        selectedVariant: selectedVariant ?? this.selectedVariant,
        designName: designName ?? this.designName,
        designId: designId ?? this.designId,
        baseProductId: baseProductId ?? this.baseProductId,
        printPosition: printPosition ?? this.printPosition,
        uploadedDesignPath: uploadedDesignPath ?? this.uploadedDesignPath,
        size: size ?? this.size,
        material: material ?? this.material,
        measurements: measurements ?? this.measurements,
        stitching: stitching ?? this.stitching,
      );
}
