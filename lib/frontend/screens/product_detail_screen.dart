import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/navigation_service.dart';
import '../data/product_catalog.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/product_variant.dart';
import '../providers/app_state.dart';
import '../../ui/widgets/variant_selector.dart';
import '../../ui/widgets/catalogue_image.dart';
import 'design_screen.dart';
import 'cardboard_template_screen.dart';
import 'plain_product_picker_screen.dart';

/// Product details screen that handles three distinct product types:
///
///   **Base/plain** — "CHOOSE A DESIGN" → design screen → customize → cart
///   **Ready-Made** — "ADD TO CART" directly (already printed)
///   **Design**     — "Choose a Product to Print On" → plain picker → customize
///
/// No step/process UI. The CTA clearly communicates what happens next.
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  String? _selectedVariantLabel;
  String? _selectedSize;

  int _galleryIndex = 0;

  /// Up to four real photos for this product: its own image first, then other
  /// product photos from the same category/subcategory. Resolved once because
  /// the catalogue is effectively static during a session.
  late final List<String> _galleryImages = _resolveGallery();

  Product get product => widget.product;
  bool get isBaseProduct => product.isBase;
  bool get isReadyMadeProduct => product.isReadyMade;
  bool get isDesignProduct => product.isDesign;

  static String _baseName(Product base) =>
      base.name.startsWith('Plain ') ? base.name.substring(6) : base.name;

  List<String> _resolveGallery() {
    final images = <String>[product.imagePath];
    for (final p in ProductCatalog.products) {
      if (p.id == product.id) continue;
      if (p.category != product.category) continue;
      if (p.subcategory.isNotEmpty &&
          p.subcategory != product.subcategory) {
        continue;
      }
      if (!images.contains(p.imagePath)) images.add(p.imagePath);
      if (images.length >= 4) break;
    }
    return images;
  }

  @override
  void initState() {
    super.initState();
    if (product.variants.isNotEmpty) {
      _selectedVariantLabel = product.variants.first.label;
    }
    if (product.availableSizes.isNotEmpty) {
      _selectedSize = product.availableSizes.first;
    }
  }

  ProductVariant? get _selectedVariant =>
      ProductCatalog.variantFor(product, _selectedVariantLabel);

  String get _variantLabel {
    final v = _selectedVariant;
    if (v == null) return '';
    return v.isColor ? 'Color' : 'Option';
  }

  void _continueToDesign() {
    final variant = _selectedVariant;
    // Cardboards are template-driven: choosing a design means picking a
    // template and entering the matter, so route to the dedicated flow.
    if (product.category == 'Cardboard') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardboardTemplateScreen(
            baseProduct: product,
            selectedVariant: variant?.label,
            selectedSize: _selectedSize,
            quantity: _quantity,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DesignScreen(
          initialCategory: product.category,
          baseProduct: product,
          selectedVariant: variant?.label,
          selectedSize: _selectedSize,
          quantity: _quantity,
        ),
      ),
    );
  }

  void _addToCart() {
    final appState = Provider.of<AppState>(context, listen: false);
    final item = CartItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: product.name,
      category: product.category,
      customText: '',
      selectedSide: _selectedVariantLabel ?? 'Default',
      fontFamily: 'Sans-Serif',
      price: product.basePrice,
      color: Colors.black,
      imagePath: product.imagePath,
      quantity: _quantity,
      baseProductTitle: null,
      baseProductId: product.id,
      selectedVariant: _selectedVariantLabel,
      size: _selectedSize,
      material: product.material,
      measurements: product.measurements,
    );
    appState.addToCart(item);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.name} added to cart'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Large Product Image ──
                  SizedBox(
                    width: double.infinity,
                    height: 300,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CatalogueImage(
                          key: const ValueKey('detail-hero'),
                          imagePath:
                              _galleryImages[_galleryIndex % _galleryImages.length],
                          fit: BoxFit.cover,
                        ),
                        // ── Type badge ──
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _typeBadgeColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _typeBadgeLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Photo gallery thumbnails ──
                  if (_galleryImages.length > 1)
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: _galleryImages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final selected = index == _galleryIndex;
                          return GestureDetector(
                            key: ValueKey('gallery-thumb-$index'),
                            onTap: () =>
                                setState(() => _galleryIndex = index),
                            child: Container(
                              width: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF6C5CE7)
                                      : Colors.grey.shade300,
                                  width: selected ? 2.5 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CatalogueImage(
                                  imagePath: _galleryImages[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Category Badge ──
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            product.category,
                            style: const TextStyle(
                                color: Color(0xFF6C5CE7),
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ── Product Name ──
                        Text(product.name,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),

                        // ── Price ──
                        Text(
                          '₹${product.basePrice.toInt()}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C5CE7)),
                        ),
                        const SizedBox(height: 10),

                        // ── Trust row ──
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: const [
                            _TrustChip(
                                icon: Icons.local_shipping_outlined,
                                label: 'Free delivery from ₹499'),
                            _TrustChip(
                                icon: Icons.autorenew_rounded,
                                label: 'Easy 10-day returns'),
                            _TrustChip(
                                icon: Icons.verified_user_outlined,
                                label: 'Secure payment'),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Description ──
                        Text(product.description,
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.5)),
                        const SizedBox(height: 20),

                        // ── Material & Details ──
                        if (product.tags.isNotEmpty) ...[
                          _InfoSection(
                            title: 'Material & Details',
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: product.tags.take(6).map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(tag,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700)),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Variant Selection ──
                        if (product.variants.isNotEmpty) ...[
                          _InfoSection(
                            title: isReadyMadeProduct
                                ? 'Select $_variantLabel'
                                : isBaseProduct
                                    ? 'Choose a $_variantLabel'
                                    : 'Options',
                            child: VariantSelector(
                              variants: product.variants,
                              selectedLabel: _selectedVariantLabel,
                              onSelected: (label) =>
                                  setState(() => _selectedVariantLabel = label),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Size Selection ──
                        if (product.availableSizes.isNotEmpty) ...[
                          _InfoSection(
                            title: 'Available Sizes',
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: product.availableSizes.map((size) {
                                final isSelected = size == _selectedSize;
                                return ChoiceChip(
                                  label: Text(size),
                                  selected: isSelected,
                                  onSelected: (sel) => setState(() {
                                    if (sel) _selectedSize = size;
                                  }),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Product-Specific Details ──
                        _buildProductSpecificDetails(),

                        // ── Supported Print Positions (base only) ──
                        if (isBaseProduct &&
                            product.supportedPrintPositions.isNotEmpty) ...[
                          _InfoSection(
                            title: 'Printable Area',
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: product.supportedPrintPositions
                                  .map((pos) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C5CE7)
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF6C5CE7)
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.print,
                                          size: 14,
                                          color: Color(0xFF6C5CE7)),
                                      const SizedBox(width: 4),
                                      Text(pos,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF6C5CE7))),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Quantity ──
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Text('Quantity:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const Spacer(),
                              IconButton(
                                onPressed: _quantity > 1
                                    ? () => setState(() => _quantity--)
                                    : null,
                                icon: const Icon(
                                    Icons.remove_circle_outline),
                              ),
                              Text('$_quantity',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _quantity++),
                                icon: const Icon(
                                    Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Price Summary ──
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Base Price:',
                                      style: TextStyle(fontSize: 14)),
                                  Text('₹${product.basePrice.toInt()}',
                                      style:
                                          const TextStyle(fontSize: 14)),
                                ],
                              ),
                              if (_quantity > 1)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Quantity:',
                                        style: TextStyle(fontSize: 14)),
                                    Text('× $_quantity',
                                        style:
                                            const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total:',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                    '₹${(product.basePrice * _quantity).toInt()}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6C5CE7)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // ── Persistent (sticky) action bar ──
      // The primary action always stays visible so the customer never has to
      // scroll back up to add to cart / start customizing.
      bottomNavigationBar: _buildStickyActionBar(context),
    );
  }

  // ─── CTA Buttons ────────────────────────────────────────────────────────

  Widget _buildAddToCartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _addToCart,
        icon: const Icon(Icons.shopping_cart_rounded),
        label: const Text('ADD TO CART',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildChooseDesignButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _continueToDesign,
        icon: const Icon(Icons.palette),
        label: const Text('CHOOSE A DESIGN',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildChooseProductButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlainProductPickerScreen(
                design: product,
                selectedSize: _selectedSize,
                quantity: _quantity,
              ),
            ),
          );
        },
        icon: const Icon(Icons.checkroom),
        label: const Text('Choose a Product to Print On',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── Sticky action bar ──────────────────────────────────────────────

  /// Fixed bottom bar that keeps the primary CTA visible regardless of scroll
  /// position (requirement: the action must not be buried at the end of a long
  /// product description).
  Widget _buildStickyActionBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPrimaryCta(),
            const SizedBox(height: 6),
            _buildCtaCaption(context),
          ],
        ),
      ),
    );
  }

  /// The primary CTA dispatched by product type (ready-made -> add to cart,
  /// base -> choose a design, design -> pick a plain product).
  Widget _buildPrimaryCta() {
    if (isReadyMadeProduct) return _buildAddToCartButton();
    if (isBaseProduct) return _buildChooseDesignButton();
    return _buildChooseProductButton();
  }

  /// One-line context caption shown under the button so the customer knows what
  /// the action means for this product type.
  Widget _buildCtaCaption(BuildContext context) {
    final String caption;
    if (isReadyMadeProduct) {
      caption = 'This product is already printed and ready to ship.';
    } else if (isBaseProduct) {
      caption = 'Choose a design to personalize this ${_baseName(product)}.';
    } else {
      caption = 'Select a plain product, then customize this design';
    }
    return Center(
      child: Text(
        caption,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
    );
  }

  // ─── Type badge helpers ──────────────────────────────────────────────────

  Color get _typeBadgeColor {
    if (isReadyMadeProduct) return Colors.green;
    if (isBaseProduct) return const Color(0xFF6C5CE7);
    return Colors.orange;
  }

  String get _typeBadgeLabel {
    if (isReadyMadeProduct) return 'Ready-Made';
    if (isBaseProduct) return 'Plain Product';
    return 'Design';
  }

  // ─── Product-specific details ────────────────────────────────────────────

  Widget _buildProductSpecificDetails() {
    final rows = <Widget>[];
    if (product.material != null && product.material!.isNotEmpty) {
      rows.add(_detailRow('Material', product.material!));
    }
    for (final m in product.measurements) {
      if (m.value.isNotEmpty) {
        rows.add(_detailRow(m.key, m.value));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return _InfoSection(
      title: 'Product Details',
      child: Column(children: rows),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _InfoSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// A compact reassurance chip ("Free delivery from ₹499", ...) shown on the
/// product detail page so the shopfront feels like a real e-commerce store.
class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF6C5CE7)),
        const SizedBox(width: 5),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ),
      ],
    );
  }
}
