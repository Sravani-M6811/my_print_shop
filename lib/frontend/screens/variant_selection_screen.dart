import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/product_variant.dart';
import '../../ui/widgets/variant_selector.dart';
import '../../ui/widgets/catalogue_image.dart';

/// Step 2 of the "Start With a Product" journey:
///   Product  ->  Colour / Variant  ->  Design  ->  Customize  ->  Cart
///
/// Lets the customer pick the available colour or option for their chosen
/// plain product, then continues to the narrowed design gallery. The chosen
/// variant is returned to the caller so it flows all the way to the cart and
/// the order.
class VariantSelectionScreen extends StatefulWidget {
  final Product baseProduct;

  /// The currently chosen variant label, when re-opening to change it.
  final String? initialVariant;

  const VariantSelectionScreen({
    super.key,
    required this.baseProduct,
    this.initialVariant,
  });

  @override
  State<VariantSelectionScreen> createState() => _VariantSelectionScreenState();
}

class _VariantSelectionScreenState extends State<VariantSelectionScreen> {
  late String _selected;

  String get _defaultLabel => widget.baseProduct.variants.isEmpty
      ? ''
      : widget.baseProduct.variants.first.label;

  bool get _isColorOptions =>
      widget.baseProduct.variants.isNotEmpty &&
      widget.baseProduct.variants.first.isColor;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialVariant ?? _defaultLabel;
  }

  static String _baseLabel(Product base) =>
      base.name.startsWith('Plain ') ? base.name.substring(6) : base.name;

  @override
  Widget build(BuildContext context) {
    final base = widget.baseProduct;
    final variants = base.variants;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Product Options',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product header ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CatalogueImage(
                    imagePath: base.imagePath,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your chosen product',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      Text(base.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(base.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 6),
                      Text('From ₹${base.basePrice.toInt()}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6C5CE7))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Variant picker ──
            Text(
              _isColorOptions ? 'Choose a Color' : 'Choose an Option',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _isColorOptions
                  ? 'Pick the color of your ${_baseLabel(base)}, then choose a design.'
                  : 'Pick the option for your ${_baseLabel(base)}, then choose a design.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            if (variants.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No options listed for ${base.name} yet.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              )
            else
              VariantSelector(
                variants: variants,
                selectedLabel: _selected,
                onSelected: (label) => setState(() => _selected = label),
              ),

            const SizedBox(height: 28),

            // ── Continue ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(
                  _selectedVariantFor(_selected),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Continue to Designs',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Next: choose a design for your ${_baseLabel(base)}.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ProductVariant? _selectedVariantFor(String label) {
    for (final v in widget.baseProduct.variants) {
      if (v.label == label) return v;
    }
    return widget.baseProduct.variants.isEmpty
        ? null
        : widget.baseProduct.variants.first;
  }
}
