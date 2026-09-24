import 'package:flutter/material.dart';
import '../../frontend/models/product.dart';
import 'catalogue_image.dart';

/// Reusable design/product card used across the Design gallery, search results
/// and the Home showcase. Driven entirely by a [Product] record so future
/// designs need no new UI — just a new data record/image.
class DesignCard extends StatelessWidget {
  final Product product;

  /// Called when the card image/body is tapped (e.g. browse details).
  final VoidCallback? onTap;

  /// Called when the "Customize" action is tapped.
  final VoidCallback? onCustomize;

  /// Optional secondary "Apply to a plain product" action used in the Design
  /// gallery to start the Design -> Product flow. When null, only the
  /// "Customize" action is shown.
  final VoidCallback? onApplyToProduct;

  const DesignCard({
    super.key,
    required this.product,
    this.onTap,
    this.onCustomize,
    this.onApplyToProduct,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CatalogueImage(
                    imagePath: product.imagePath,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.category,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '₹${product.basePrice.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF6C5CE7),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 24,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                                padding: EdgeInsets.zero,
                                side: BorderSide(color: theme.colorScheme.primary, width: 1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              onPressed: onCustomize ?? onTap,
                              child: const Text('Customize'),
                            ),
                          ),
                        ),
                        if (onApplyToProduct != null) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            height: 24,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w600),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: onApplyToProduct,
                              child: const Text('Plain'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
