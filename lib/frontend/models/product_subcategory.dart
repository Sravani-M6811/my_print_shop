import 'package:flutter/material.dart';

/// A data-driven sub-division of a [ProductCategory].
///
/// The catalogue is organised as category -> sub-categories -> plain products.
/// Each sub-category carries the display copy and a set of [aliases] that map
/// it onto the `subcategory` labels used on the underlying [Product] records,
/// so a customer-facing name (e.g. "Silk Plain") can aggregate several
/// record-level values (e.g. "Silk Plain Sarees") without renaming the data.
class ProductSubcategory {
  /// Stable machine identifier, e.g. 'sarees_silk_plain'.
  final String id;

  /// The owning category's stable id (see [ProductCategory.id]) or its display
  /// name.
  final String categoryId;

  /// Customer-facing sub-category name, e.g. 'Silk Plain'.
  final String name;

  /// Record-level `subcategory` values on [Product]s that belong to this
  /// sub-category. When empty, [designType] is used to resolve ready-made /
  /// design records instead of base products.
  final List<String> aliases;

  /// When a sub-category maps onto a design type (e.g. Embroidery "Floral")
  /// instead of base products, this matches the `designType` on design/ready
  /// made records. Null when the sub-category is served by base products.
  final String? designType;

  /// Representative image for the tile. When null the screen falls back to the
  /// category's representative image.
  final String? imagePath;

  /// Short marketing line shown under the tile name.
  final String tagline;

  /// Short description shown on the individual sub-category screen.
  final String description;

  /// Icon shown as a fallback / accent on the tile.
  final IconData icon;

  const ProductSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    this.aliases = const [],
    this.designType,
    this.imagePath,
    this.tagline = '',
    this.description = '',
    this.icon = Icons.category_outlined,
  });
}