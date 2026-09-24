import 'package:flutter/material.dart';
import '../data/product_catalog.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/product_subcategory.dart';
import '../services/category_image_catalog.dart';
import '../../ui/widgets/catalogue_image.dart';
import 'product_detail_screen.dart';
import 'subcategory_catalogue_screen.dart';

/// Sectioned category catalogue screen.
///
/// For every category this renders:
///   1. A search bar
///   2. Optional selectable colour filter chips (functional, filters products)
///   3. One section/row per named sub-category, each a horizontal carousel on
///      narrow screens and a responsive grid on wide screens.
///
/// It is fully data-driven from [Product.subcategory] records — no per-category
/// UI code. Products inside each row open [ProductDetailScreen].
class CategoryCatalogueScreen extends StatefulWidget {
  final ProductCategory category;
  const CategoryCatalogueScreen({super.key, required this.category});

  @override
  State<CategoryCatalogueScreen> createState() =>
      _CategoryCatalogueScreenState();
}

class _CategoryCatalogueScreenState extends State<CategoryCatalogueScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedColour;

  ProductCategory get category => widget.category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Subcategories to show. Folded into one row when searching so results read
  /// as a single filtered list rather than many near-empty sections.
  List<String> get _sections =>
      ProductCatalog.subcategoriesForCategory(category.name);

  /// The distinct selectable colours across this category's plain products.
  List<String> get _availableColours {
    final colours = <String>[];
    for (final p in ProductCatalog.products) {
      if (p.category != category.name) continue;
      for (final c in p.availableColors) {
        if (!colours.contains(c)) colours.add(c);
      }
    }
    return colours;
  }

  bool get _isSearching => _query.trim().isNotEmpty;

  List<Product> _productsInSection(String section) {
    var list = ProductCatalog.productsForSubcategory(category.name, section);
    if (_isSearching) {
      list = list.where((p) => p.matches(_query)).toList();
    }
    if (_selectedColour != null) {
      list = list
          .where((p) => p.availableColors.contains(_selectedColour))
          .toList();
    }
    return list;
  }

  List<Product> _allFiltered() {
    var list = ProductCatalog.products
        .where((p) =>
            p.category == category.name &&
            p.subcategory.isNotEmpty &&
            !p.isReadyMade)
        .toList();
    if (_isSearching) {
      list = list.where((p) => p.matches(_query)).toList();
    }
    if (_selectedColour != null) {
      list = list
          .where((p) => p.availableColors.contains(_selectedColour))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          category.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search ${category.name}…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              ),
            ),
          ),

          // ── Category hero banner ──
          _CategoryBanner(category: category),

          // ── Colour filter (only when colours exist) ──
          if (_availableColours.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                children: [
                  _colourChip('All', null),
                  for (final c in _availableColours) _colourChip(c, c),
                ],
              ),
            ),

          Expanded(
            child: _sections.isEmpty
                ? const SizedBox.shrink()
                : _isSearching
                    ? _filteredView(theme)
                    : _sectionedView(theme),
          ),
        ],
      ),
    );
  }

  Widget _colourChip(String label, String? value) {
    final selected = _selectedColour == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _selectedColour = value),
      ),
    );
  }

  // When searching, show a single unified list of matching products.
  Widget _filteredView(ThemeData theme) {
    final results = _allFiltered();
    if (results.isEmpty) {
      return const Center(
        child: Text('No matching products',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${results.length} result${results.length == 1 ? '' : 's'}',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _SectionedLayout(products: results),
      ],
    );
  }

  // Normal browsing: sub-category tiles first, then one labelled row per
  // record-level sub-category for the full range.
  Widget _sectionedView(ThemeData theme) {
    final visibleSections = _sections.toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SubcategoryTileGrid(category: category),
        for (final section in visibleSections)
          _CatalogueSection(
            title: section,
            products: _productsInSection(section),
          ),
      ],
    );
  }
}

// ─── Sub-category tiles (entry into individual sub-category screens) ────────
class _SubcategoryTileGrid extends StatelessWidget {
  final ProductCategory category;
  const _SubcategoryTileGrid({required this.category});

  @override
  Widget build(BuildContext context) {
    final subs = ProductCatalog.subcategoriesFor(category.name);
    if (subs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Text(
            'Sub-Categories',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final sub in subs)
                _SubcategoryTile(
                  subcategory: sub,
                  imagePath: CategoryImageCatalog.subcategoryImage(
                    categoryName: category.name,
                    subcategoryName: sub.name,
                    bundledPath:
                        sub.imagePath?.isNotEmpty == true
                            ? sub.imagePath!
                            : category.imagePath,
                  ),
                  fallbackImage: category.imagePath,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SubcategoryCatalogueScreen(
                        subcategory: sub,
                        category: category.name,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  final ProductSubcategory subcategory;
  final String imagePath;
  final String fallbackImage;
  final VoidCallback onTap;
  const _SubcategoryTile({
    required this.subcategory,
    required this.imagePath,
    required this.fallbackImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final plainCount = ProductCatalog.baseProductsForSubcategory(subcategory).length;

    final width = (MediaQuery.of(context).size.width - 44) / 2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CatalogueImage(
                imagePath: imagePath,
                fallbackImage: fallbackImage,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subcategory.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  if (subcategory.tagline.isNotEmpty)
                    Text(
                      subcategory.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade600),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '$plainCount products',
                    style: TextStyle(
                        fontSize: 10,
                        color: const Color(0xFF6C5CE7),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─── Category hero banner ──────────────────────────────────────────────────
class _CategoryBanner extends StatelessWidget {
  final ProductCategory category;
  const _CategoryBanner({required this.category});

  @override
  Widget build(BuildContext context) {
    // Count only catalogue products (plain/base + ready-made), never design
    // records, so the banner reflects the product catalogue this screen shows
    // instead of mixing in the design gallery's count.
    final count = ProductCatalog.products
        .where((p) =>
            p.category == category.name &&
            !p.isDesign)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF4B3FBF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CatalogueImage(
                imagePath: CategoryImageCatalog.categoryImage(
                  categoryName: category.name,
                  bundledPath: category.imagePath,
                ),
                fallbackImage: category.imagePath,
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
                    category.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count products · custom printing available',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

// ─── A single labelled row of products ─────────────────────────────────────
class _CatalogueSection extends StatelessWidget {
  final String title;
  final List<Product> products;
  const _CatalogueSection({required this.title, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _SectionedLayout(products: products),
      ],
    );
  }
}

// ─── Responsive layout: horizontal carousel (mobile) / grid (wide) ─────────
class _SectionedLayout extends StatelessWidget {
  final List<Product> products;
  const _SectionedLayout({required this.products});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 760) {
      return _ProductGrid(products: products);
    }
    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _CatalogueProductCard(
          product: products[index],
          width: 170,
          onTap: _open(context, products[index]),
        ),
      ),
    );
  }

  VoidCallback _open(BuildContext context, Product product) => () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      };
}

// ─── Wide-screen responsive grid ───────────────────────────────────────────
class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  const _ProductGrid({required this.products});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1400
            ? 5
            : width >= 1100
                ? 4
                : width >= 760
                    ? 3
                    : 2;
        const crossAxisSpacing = 14.0;
        const horizontalPadding = 16.0;
        final cardWidth = (width -
                (horizontalPadding * 2) -
                (crossAxisSpacing * (crossAxisCount - 1))) /
            crossAxisCount;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: 14,
            childAspectRatio: crossAxisCount >= 4 ? 0.82 : 0.78,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => _CatalogueProductCard(
            product: products[index],
            width: cardWidth,
            onTap: _open(context, products[index]),
          ),
        );
      },
    );
  }

  VoidCallback _open(BuildContext context, Product product) => () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      };
}

// ─── Catalogue product card ────────────────────────────────────────────────
class _CatalogueProductCard extends StatelessWidget {
  final Product product;
  final double? width;
  final VoidCallback? onTap;
  const _CatalogueProductCard({required this.product, this.width, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image ──
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _materialLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Info ──
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (product.material != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      product.material!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        product.isAvailable
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 11,
                        color: product.isAvailable
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        product.isAvailable ? 'In Stock' : 'Unavailable',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: product.isAvailable
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'From ₹${product.basePrice.toInt()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6C5CE7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 26,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          onPressed: onTap,
                          child: const Text('View'),
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

    if (width != null) {
      return SizedBox(width: width, child: card);
    }
    return card;
  }

  String get _materialLabel => product.material?.isNotEmpty == true
      ? (product.material!.split(RegExp(r'[ /]')).first)
      : product.category;
}
