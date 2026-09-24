import 'package:flutter/material.dart';

/// A selectable colour / variant for a plain (base) product that a customer
/// picks *before* choosing a design, e.g. "Plain T-Shirt" -> "Black".
///
/// Models two shapes of choice without inventing unrealistic options:
///   * real colours (fabric/ceramic/glass tints) rendered as swatches, and
///   * non-colour choices such as poster finishes ("Matte", "Glossy",
///     "Premium") or glass finishes, rendered as labelled chips.
///
/// This is a tiny value object stored on the existing [Product] record, so
/// growing the option list for any base product is purely data-driven and
/// never requires new UI code.
class ProductVariant {
  final String label;

  /// True when this option is a real colour shown as a swatch; false renders
  /// it as a selectable chip/card (e.g. "Matte", "Premium").
  final bool isColor;

  /// The swatch colour when [isColor] is true (ARGB int).
  final int colorValue;

  const ProductVariant({
    required this.label,
    this.isColor = false,
    this.colorValue = 0xFF607D8B,
  });

  /// The colour used for a swatch when [isColor] is true; a neutral tone for
  /// non-colour chips (their chip background is theme-themed instead).
  Color get swatchColor => isColor ? Color(colorValue) : const Color(0xFFECEFF1);

  /// Readable check-mark colour for a given swatch (dark swatch -> light tick).
  Color get checkColor =>
      swatchColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  @override
  bool operator ==(Object other) =>
      other is ProductVariant && other.label == label;

  @override
  int get hashCode => label.hashCode;

  @override
  String toString() => label;
}