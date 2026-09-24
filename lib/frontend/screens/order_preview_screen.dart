import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/asset_paths.dart';
import '../core/navigation_service.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/app_state.dart';
import '../data/product_catalog.dart';
import '../../ui/widgets/step_indicator.dart';

/// Step 4 of the product-first journey (Base -> Design -> Customize -> Preview
/// -> Cart). Shows a clear summary of the complete configuration — selected
/// plain product, its options/measurements, the chosen (or uploaded) design,
/// print position, quantity and the final price — before the customer commits
/// it to the cart.
///
/// The screen receives everything it needs to render the preview and, when the
/// customer confirms, it constructs the fully-populated [CartItem] and adds it
/// to the cart. This keeps the cart line rich (base product + design + variant
/// + print position + uploaded reference) instead of a bare "Custom T-Shirt".
class OrderPreviewScreen extends StatefulWidget {
  final Product baseProduct;
  final String? selectedVariant;
  final String? selectedSize;
  final Product? design;
  final String? uploadedImagePath;
  final String customText;
  final String fontFamily;
  final String printPosition;
  final int quantity;

  /// Stitching option for Dress Materials (e.g. 'With Stitching' /
  /// 'Without Stitching'). Carried onto the cart item and order. Null when not
  /// applicable so other categories and existing data remain unaffected.
  final String? stitching;

  const OrderPreviewScreen({
    super.key,
    required this.baseProduct,
    this.selectedVariant,
    this.selectedSize,
    this.design,
    this.uploadedImagePath,
    this.customText = '',
    this.fontFamily = 'Sans-Serif',
    this.printPosition = 'Front',
    this.quantity = 1,
    this.stitching,
  });

  @override
  State<OrderPreviewScreen> createState() => _OrderPreviewScreenState();
}

class _OrderPreviewScreenState extends State<OrderPreviewScreen> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.quantity > 0 ? widget.quantity : 1;
  }

  String get _variantLabel {
    final base = widget.baseProduct;
    return ProductCatalog.variantFor(base, widget.selectedVariant)?.isColor ==
            true
        ? 'Color'
        : 'Option';
  }

  double get _basePrice => widget.baseProduct.basePrice;

  double get _lineTotal => _basePrice * _quantity;

  void _addToCart() {
    final appState = Provider.of<AppState>(context, listen: false);
    final base = widget.baseProduct;
    final design = widget.design;

    final item = CartItem(
      id: 'ITEM${DateTime.now().microsecondsSinceEpoch.toString()}',
      title: base.name.startsWith('Plain ')
          ? '${base.name} · ${design?.name ?? 'Custom Design'}'
          : '${base.name} · ${design?.name ?? 'Custom Design'}',
      category: base.category,
      customText: widget.customText,
      selectedSide: widget.printPosition,
      fontFamily: widget.fontFamily,
      price: _basePrice,
      color: _variantColor,
      imagePath: widget.uploadedImagePath ?? design?.imagePath,
      quantity: _quantity,
      baseProductTitle: base.name,
      baseProductId: base.id,
      selectedVariant: widget.selectedVariant,
      size: widget.selectedSize,
      material: base.material,
      measurements: base.measurements,
      designName: design?.name,
      designId: design?.id,
      printPosition: widget.printPosition,
      uploadedDesignPath: widget.uploadedImagePath,
      stitching: widget.stitching,
    );
    appState.addToCart(item);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Added to Cart!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'PROCEED TO CHECKOUT',
            textColor: Colors.white,
            onPressed: () {
              // Return to the shell (pop any pushed routes) then open the Cart
              // tab so the user isn't left stranded on a pushed detail screen.
              Navigator.of(context)
                  .popUntil((route) => route.isFirst);
              NavigationService.instance.openCart();
            },
          ),
        ),
      );
  }

  Color get _variantColor {
    final v = ProductCatalog.variantFor(widget.baseProduct, widget.selectedVariant);
    return v?.isColor == true ? v!.swatchColor : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Your Product',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
        ),
      ),
      body: Column(
        children: [
          const StepIndicator(
            steps: ['Product', 'Design', 'Customize', 'Preview', 'Cart'],
            currentIndex: 3,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Preview mockup ──
                  Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          AssetPaths.productImageForCategory(widget.baseProduct.category),
                          width: 160,
                          height: 160,
                          fit: BoxFit.contain,
                          opacity: const AlwaysStoppedAnimation(0.35),
                        ),
                        if (widget.uploadedImagePath != null &&
                            widget.uploadedImagePath!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _image(widget.uploadedImagePath!, 110, 110),
                          )
                        else if (widget.design != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _designThumb(
                                widget.design!.imagePath, 110, 110),
                          ),
                        if (widget.customText.isNotEmpty)
                          Positioned(
                            bottom: 24,
                            child: Text(
                              widget.customText,
                              style: TextStyle(
                                color: _variantColor.computeLuminance() < 0.5
                                    ? Colors.white
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                fontFamily: widget.fontFamily,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Configuration summary ──
                  Text('Your Configuration',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    children: [
                      _row('Base Product', widget.baseProduct.name),
                      _row('Category', widget.baseProduct.category),
                      if (widget.selectedVariant != null &&
                          widget.selectedVariant!.isNotEmpty)
                        _row(_variantLabel, widget.selectedVariant!),
                      if (widget.selectedSize != null &&
                          widget.selectedSize!.isNotEmpty)
                        _row('Size', widget.selectedSize!),
                      if (widget.baseProduct.material != null &&
                          widget.baseProduct.material!.isNotEmpty)
                        _row('Material', widget.baseProduct.material!),
                      if (widget.design != null)
                        _row('Design', widget.design!.name),
                      if (widget.uploadedImagePath != null &&
                          widget.uploadedImagePath!.isNotEmpty)
                        _row('Artwork', 'Your uploaded design'),
                      if (widget.stitching != null &&
                          widget.stitching!.isNotEmpty)
                        _row('Stitching', widget.stitching!),
                      _row('Print Position', widget.printPosition),
                      _row('Custom Text',
                          widget.customText.isEmpty ? '—' : '"${widget.customText}"'),
                      _row('Font', widget.fontFamily),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Quantity ──
                  Row(
                    children: [
                      const Text('Quantity:',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      IconButton(
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$_quantity',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => setState(() => _quantity++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Price breakdown ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _priceRow('Base Price',
                            '₹${widget.baseProduct.basePrice.toInt()}'),
                        if (_quantity > 1)
                          _priceRow('Quantity',
                              '$_quantity × ₹${widget.baseProduct.basePrice.toInt()}'),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              '₹${_lineTotal.toInt()}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6C5CE7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Add to cart ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        _addToCart();
                      },
                      icon: const Icon(Icons.shopping_cart),
                      label: Text(
                        'Add to Cart (₹${_lineTotal.toInt()})',
                        style:
                            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders a design image whose source can be a real network URL (uploaded to
  /// Firebase Storage), a bundled asset, or a local file path (offline upload
  /// fallback / web blob URL). Each source uses the correct renderer; loading a
  /// local path through Image.network would simply never resolve.
  Widget _image(String path, double w, double h) {
    final isHttp =
        path.startsWith('http://') || path.startsWith('https://');
    if (isHttp) {
      return Image.network(
        path,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    if (path.startsWith('asset')) {
      return Image.asset(
        path.startsWith('asset:') ? path.substring(6) : path,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    // Local picker file (native) or blob URL (web).
    return kIsWeb
        ? Image.network(
            path,
            width: w,
            height: h,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        : Image.file(
            File(path),
            width: w,
            height: h,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
  }

  /// Renders a design thumbnail from either a bundled asset or a remote URL
  /// (e.g. a live Pexels design) with the same fallback decoration.
  Widget _designThumb(String path, double w, double h) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _thumbFallback(w, h),
      );
    }
    return Image.asset(
      path,
      width: w,
      height: h,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _thumbFallback(w, h),
    );
  }

  Widget _thumbFallback(double w, double h) => Container(
        width: w,
        height: h,
        color: Colors.grey.shade700,
        child: const Icon(Icons.palette, color: Colors.white, size: 34),
      );

Widget _row(String label, String value) => Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );

  Widget _priceRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  final List<Widget> children;
  const _SummaryCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
