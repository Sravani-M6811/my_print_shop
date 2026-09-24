import 'package:flutter/material.dart';
import 'product_subcategory.dart';

/// A data-driven descriptor for a product category.
///
/// The catalogue is driven by a list of these records rather than hardcoding
/// category visuals/sections into each screen, so expanding the store later
/// only means adding another [ProductCategory] (plus the matching Product and
/// Design records) — never new UI code.
class ProductCategory {
  /// Stable machine identifier, e.g. 'sarees'. Independent of the display
  /// [name] so a rename never breaks references.
  final String id;

  /// Human-facing category name, e.g. 'Sarees'. This must match the
  /// `category` value used on the [Product] records so filtering by name stays
  /// consistent across the whole catalogue.
  final String name;

  /// Representative image shown on the category card / browse entry point.
  final String imagePath;

  /// Short marketing line shown under the category name on the card.
  final String tagline;

  /// Short description of what the category offers.
  final String description;

  /// Icon shown as a lightweight fallback / accent on the card.
  final IconData icon;

  /// The sub-categories offered by this category, resolved individually in the
  /// category catalogue screen. Data-driven so adding a section is a data
  /// change, never a UI change.
  final List<ProductSubcategory> subcategories;

  const ProductCategory({
    required this.id,
    required this.name,
    required this.imagePath,
    this.tagline = '',
    this.description = '',
    this.icon = Icons.category,
    this.subcategories = const [],
  });

  /// The sub-category with the matching [ProductSubcategory.id], or null.
  ProductSubcategory? subcategoryById(String id) {
    for (final sub in subcategories) {
      if (sub.id == id) return sub;
    }
    return null;
  }
}
