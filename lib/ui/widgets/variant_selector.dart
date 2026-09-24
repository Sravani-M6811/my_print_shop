import 'package:flutter/material.dart';
import '../../frontend/models/product_variant.dart';

/// Reusable picker for a plain product's colours / variants.
///
/// Renders real colour options as circular swatches with a selection ring and
/// check mark, and non-colour options (e.g. "Matte", "Premium") as labelled
/// chips. Options wrap on narrow screens so mobile never overflows
/// horizontally.
class VariantSelector extends StatelessWidget {
  final List<ProductVariant> variants;
  final String? selectedLabel;
  final ValueChanged<String> onSelected;

  const VariantSelector({
    super.key,
    required this.variants,
    required this.selectedLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final variant in variants)
          VariantOptionTile(
            theme: theme,
            variant: variant,
            selected: variant.label == selectedLabel,
            onTap: () => onSelected(variant.label),
          ),
      ],
    );
  }
}

/// A single selectable option: swatch (colour) or chip (non-colour).
class VariantOptionTile extends StatelessWidget {
  final ThemeData theme;
  final ProductVariant variant;
  final bool selected;
  final VoidCallback onTap;

  const VariantOptionTile({
    super.key,
    required this.theme,
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: variant.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: variant.isColor ? _buildColorTile() : _buildOptionChip(),
      ),
    );
  }

  Widget _buildColorTile() {
    final primary = theme.colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? primary : Colors.grey.shade300,
              width: selected ? 2.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: variant.swatchColor,
            ),
            child: selected
                ? Icon(Icons.check, size: 20, color: variant.checkColor)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          variant.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? primary : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionChip() {
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? primary.withValues(alpha: 0.1)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? primary : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            Icon(Icons.check, size: 16, color: primary),
            const SizedBox(width: 6),
          ],
          Text(
            variant.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? primary : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
