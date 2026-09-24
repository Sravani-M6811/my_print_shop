import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_catalog.dart';
import '../models/design.dart';
import '../models/product.dart';
import '../models/product_variant.dart';
import '../providers/app_state.dart';
import '../../ui/widgets/product_card.dart';
import '../../ui/widgets/catalogue_image.dart';
import 'design_customize_screen.dart';
import 'variant_selection_screen.dart';

/// "Start from a Design" flow (Design -> Product -> Variant -> Customize).
///
/// A customer browsing the reusable [Design] collection can pick a design first
/// and then choose which compatible PLAIN / base product to print it on. The
/// selected [Design] (a [Product] record) is preserved and passed together with
/// the chosen plain product + variant into the customize screen, so nothing is
/// lost during navigation.
class PlainProductPickerScreen extends StatefulWidget {
  /// The reusable design the customer already picked.
  final Product design;

  /// The size chosen on the design's detail screen (e.g. 'L', 'XL'), preserved
  /// through Customize -> Preview -> Cart so the configuration is never lost.
  final String? selectedSize;

  /// The quantity chosen on the design's detail screen, forwarded through the
  /// customize/preview stages so it is never silently reset to 1.
  final int quantity;

  const PlainProductPickerScreen({
    super.key,
    required this.design,
    this.selectedSize,
    this.quantity = 1,
  });

  @override
  State<PlainProductPickerScreen> createState() =>
      _PlainProductPickerScreenState();
}

class _PlainProductPickerScreenState extends State<PlainProductPickerScreen> {
  Future<void> _chooseBase(Product base) async {
    final variant = await Navigator.of(context).push<ProductVariant>(
      MaterialPageRoute(
        builder: (_) => VariantSelectionScreen(baseProduct: base),
      ),
    );
    if (!mounted || variant == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: Provider.of<AppState>(context, listen: false),
          child: DesignCustomizeScreen(
            product: _designForBase(base, widget.design),
            baseProduct: base,
            selectedVariant: variant.label,
            selectedSize: widget.selectedSize,
            quantity: widget.quantity,
            title: 'Customize Design',
          ),
        ),
      ),
    );
  }

  /// The design record to print on the chosen [base]. When the base's gallery
  /// explicitly lists [design], use it as-is; otherwise fall back to the picked
  /// design so the customer's selection is never silently dropped.
  Product _designForBase(Product base, Product design) =>
      base.designIds.contains(design.id) ? design : design;

  @override
  Widget build(BuildContext context) {
    final design = widget.design;
    // Data-driven compatibility: resolve the plain products this design can be
    // printed on from the design's own compatibleProductIds /
    // compatibleCategories (falling back to the design's category). This is the
    // reverse lookup of ProductCatalog.designsForBase and keeps the picker in
    // sync with whatever the catalogue data declares.
    final compatible =
        ProductCatalog.plainProductsForDesign(Design.fromProduct(design));
    final multiCategory = compatible
        .map((p) => p.category)
        .toSet()
        .length > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Plain Product',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Selected design banner ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF4B3FBF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CatalogueImage(
                        imagePath: design.imagePath,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your selected design',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            design.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${design.category} · Now pick a blank product to print it on',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (compatible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No plain products available for ${design.category} yet.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  multiCategory
                      ? 'Compatible Plain Products'
                      : 'Plain ${design.category}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount =
                      width >= 1200 ? 4 : width >= 600 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: crossAxisCount >= 3 ? 0.8 : 0.72,
                    ),
                    itemCount: compatible.length,
                    itemBuilder: (context, index) {
                      final base = compatible[index];
                      return ProductCard(
                        product: base,
                        onTap: () => _chooseBase(base),
                      );
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
