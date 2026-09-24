import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_catalog.dart';
import '../models/product.dart';
import '../models/product_subcategory.dart';
import '../providers/app_state.dart';
import '../services/category_image_catalog.dart';
import '../../ui/widgets/catalogue_image.dart';
import '../../ui/widgets/design_card.dart';
import 'design_customize_screen.dart';
import 'product_detail_screen.dart';

/// Individual sub-category screen: the plain/base products belonging to one
/// sub-category, plus (for design-driven sub-categories such as Embroidery
/// "Floral") the matching ready-made/design records.
///
/// Long lists are loaded in pages via [ProductCatalog.pageOf] so the screen
/// stays light under the 10k-image plan instead of materializing a whole
/// catalogue.
class SubcategoryCatalogueScreen extends StatefulWidget {
  final ProductSubcategory subcategory;
  final String category;
  const SubcategoryCatalogueScreen({
    super.key,
    required this.subcategory,
    required this.category,
  });

  @override
  State<SubcategoryCatalogueScreen> createState() =>
      _SubcategoryCatalogueScreenState();
}

class _SubcategoryCatalogueScreenState extends State<SubcategoryCatalogueScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isLoadingMore = false;
  int _visibleCount = 0;
  static const int _pageSize = 48;

  late final List<Product> _baseProducts;
  late final List<Product> _designProducts;

  @override
  void initState() {
    super.initState();
    _baseProducts =
        ProductCatalog.baseProductsForSubcategory(widget.subcategory);
    _designProducts =
        ProductCatalog.designsForSubcategory(widget.subcategory);
    _visibleCount =
        (_baseProducts.length + _designProducts.length) < _pageSize
            ? _baseProducts.length + _designProducts.length
            : _pageSize;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _loadMore() {
    final total = _baseProducts.length + _designProducts.length;
    if (_isLoadingMore || _visibleCount >= total) return;
    setState(() {
      _isLoadingMore = true;
    });
    // Small tail delay keeps the UI smooth and makes the lazy-load visible.
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _visibleCount = (_visibleCount + _pageSize) > total
            ? total
            : _visibleCount + _pageSize;
        _isLoadingMore = false;
      });
    });
  }

  List<Product> get _visibleBase {
    // While searching, always consult the FULL base list so a match beyond the
    // currently loaded page is never hidden by the lazy-load window.
    if (_query.trim().isNotEmpty) {
      return _baseProducts.where((p) => p.matches(_query)).toList();
    }
    return ProductCatalog.pageOf(_baseProducts,
        page: 1, pageSize: _visibleCount);
  }

  List<Product> get _visibleDesigns {
    if (_query.trim().isNotEmpty) {
      return _designProducts.where((p) => p.matches(_query)).toList();
    }
    return ProductCatalog.pageOf(_designProducts,
        page: 1, pageSize: _visibleCount);
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subcategory;
    final designCount =
        ProductCatalog.designsForSubcategory(sub).length;
    final baseCount = _baseProducts.length;

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category}: ${sub.name}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search ${sub.name} products…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          // ── Banner ──
          _buildBanner(theme, sub),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (baseCount > 0) ...[
                    Text(
                      'Plain ${widget.category.toLowerCase()}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick a blank product, then choose your design.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    _buildBaseGrid(),
                  ],
                  if (designCount > 0 && baseCount > 0)
                    const SizedBox(height: 24),
                  if (designCount > 0) ...[
                    Text(
                      'Ready-Made & Designs',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Already printed ${widget.category.toLowerCase()} for this type.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    _buildDesignGrid(),
                  ],
                  if (baseCount == 0 && designCount == 0)
                    _buildEmpty(theme),
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(ThemeData theme, ProductSubcategory sub) {
    final categoryImage =
        ProductCatalog.categoryDescriptors
            .where((d) => d.name == widget.category)
            .isEmpty
        ? null
        : ProductCatalog.categoryDescriptors
            .firstWhere((d) => d.name == widget.category)
            .imagePath;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
            borderRadius: BorderRadius.circular(10),
            child: CatalogueImage(
              imagePath: CategoryImageCatalog.subcategoryImage(
                categoryName: widget.category,
                subcategoryName: sub.name,
                bundledPath: sub.imagePath?.isNotEmpty == true
                    ? sub.imagePath!
                    : (categoryImage ?? ''),
              ),
              fallbackImage: categoryImage ?? '',
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
                if (sub.tagline.isNotEmpty)
                  Text(
                    sub.tagline,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${_baseProducts.length} plain products'
                  '${ProductCatalog.designsForSubcategory(sub).isNotEmpty ? ' · ${ProductCatalog.designsForSubcategory(sub).length} ready-made' : ''}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseGrid() {
    final visible = _visibleBase;
    if (visible.isEmpty) return _smallEmpty('No plain products match.');
    return _ResponsiveGrid(
      products: visible,
      itemBuilder: (product) => _SubProductCard(
        product: product,
        badge: 'Plain',
        badgeColor: const Color(0xFF6C5CE7),
        ctaLabel: 'Choose Product',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        ),
      ),
    );
  }

  Widget _buildDesignGrid() {
    final visible = _visibleDesigns;
    if (visible.isEmpty) return _smallEmpty('No ready-made products match.');
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1200
            ? 6
            : width >= 900
                ? 5
                : width >= 600
                    ? 4
                    : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns >= 4 ? 0.72 : 0.68,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final product = visible[index];
            return DesignCard(
              product: product,
              onTap: () => _openCustomize(context, product),
              onCustomize: () => _openCustomize(context, product),
            );
          },
        );
      },
    );
  }

  void _openCustomize(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: Provider.of<AppState>(context, listen: false),
          child: DesignCustomizeScreen(
            product: product,
            baseProduct: null,
            selectedVariant: null,
            selectedSize: null,
            quantity: 1,
            title: product.isReadyMade ? product.name : 'Customize Design',
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.filter_alt_off_outlined,
              size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            'No products in "${widget.subcategory.name}" yet.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Browse the full ${widget.category} range from the category screen.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _smallEmpty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        message,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      ),
    );
  }
}

// ─── Responsive grid for plain products ─────────────────────────────────────

class _ResponsiveGrid extends StatelessWidget {
  final List<Product> products;
  final Widget Function(Product) itemBuilder;
  const _ResponsiveGrid({required this.products, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 4
            : width >= 900
                ? 3
                : width >= 600
                    ? 2
                    : 1;
        final childAspectRatio = crossAxisCount == 1 ? 1.35 : 0.8;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => itemBuilder(products[index]),
        );
      },
    );
  }
}

// ─── Product Card ───────────────────────────────────────────────────────────

class _SubProductCard extends StatelessWidget {
  final Product product;
  final String badge;
  final Color badgeColor;
  final String ctaLabel;
  final VoidCallback onTap;

  const _SubProductCard({
    required this.product,
    required this.badge,
    required this.badgeColor,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CatalogueImage(imagePath: product.imagePath, fit: BoxFit.cover),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '₹${product.basePrice.toInt()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: badgeColor,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: onTap,
                          child: Text(ctaLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
