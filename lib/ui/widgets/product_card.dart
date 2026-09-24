import 'package:flutter/material.dart';
import '../../frontend/models/product.dart';
import 'catalogue_image.dart';

/// E-commerce-style product card for plain/base products.
///
/// Shows product image, name, material tags, base price, and a clear CTA.
/// The card communicates the "choose this plain product" concept with a
/// "Customize This" button for base products and a "View" button for designs.
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  /// Secondary action label. Defaults to "Customize This" for base products
  /// and "View" for design products. Override with [actionLabel].
  final String? actionLabel;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBase = product.isBase;
    final isReadyMade = product.isReadyMade;
    final ctaLabel = actionLabel ??
        (isBase ? 'Customize This' : isReadyMade ? 'View' : 'View');

    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Product Image (takes remaining space after info) ──
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CatalogueImage(
                    imagePath: product.imagePath,
                    fit: BoxFit.cover,
                  ),
                  if (isBase)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Base Product',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (isReadyMade)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Ready-Made',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  // Price badge
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Text(
                        '₹${product.basePrice.toInt()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF6C5CE7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Product Info (natural height, no fixed ratio) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.tags.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.tags.take(2).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '₹${product.basePrice.toInt()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C5CE7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 26,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBase
                            ? const Color(0xFF6C5CE7)
                            : isReadyMade
                                ? Colors.green
                                : theme.colorScheme.surface,
                        foregroundColor: isBase || isReadyMade
                            ? Colors.white
                            : theme.colorScheme.primary,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: isBase || isReadyMade
                              ? BorderSide.none
                              : BorderSide(color: theme.colorScheme.primary),
                        ),
                        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      onPressed: onTap,
                      child: Text(ctaLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
