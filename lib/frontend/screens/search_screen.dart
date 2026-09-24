import 'package:flutter/material.dart';
import '../data/product_catalog.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../../ui/widgets/design_card.dart';
import '../../ui/widgets/product_card.dart';
import 'category_catalogue_screen.dart';
import 'plain_product_picker_screen.dart';
import 'product_detail_screen.dart';

/// Full-catalogue search across PLAIN PRODUCTS, reusable DESIGNS and
/// CATEGORIES. Results are grouped and clearly labelled so a result is
/// identifiable as a Product, a Design or a Category:
///
///   Categories -> matching category names (open a category browse)
///   Plain Products -> blank items you print on (open their detail / customize)
///   Designs -> reusable artwork to apply (open customize)
///
/// The search covers the complete data source (not just the Home sample), and
/// matches product name/category/variant/color, design name/tags, and category
/// name.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  String? _categoryFilter;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isSearching => _query.trim().isNotEmpty;
  String get _q => _query.trim();

  /// Categories whose name matches the query.
  List<String> get _matchingCategories =>
      ProductCatalog.categoryDescriptors
          .where((d) => d.name.toLowerCase().contains(_q.toLowerCase()))
          .map((d) => d.name)
          .toList();

  /// Plain/base products matching the query (optionally category-filtered).
  List<Product> get _plainResults {
    var r = ProductCatalog.search(_q).where((p) => p.isBase).toList();
    if (_categoryFilter != null) {
      r = r.where((p) => p.category == _categoryFilter).toList();
    }
    return r;
  }

  /// Reusable designs matching the query (optionally category-filtered).
  List<Product> get _designResults {
    var r = ProductCatalog.search(_q).where((p) => p.isDesign).toList();
    if (_categoryFilter != null) {
      r = r.where((p) => p.category == _categoryFilter).toList();
    }
    return r;
  }

  /// Ready-made products matching the query (optionally category-filtered).
  List<Product> get _readyMadeResults {
    var r = ProductCatalog.search(_q).where((p) => p.isReadyMade).toList();
    if (_categoryFilter != null) {
      r = r.where((p) => p.category == _categoryFilter).toList();
    }
    return r;
  }

  void _openDesignWithProduct(Product p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlainProductPickerScreen(design: p),
      ),
    );
  }

  bool get _hasResults =>
      _matchingCategories.isNotEmpty ||
      _plainResults.isNotEmpty ||
      _designResults.isNotEmpty ||
      _readyMadeResults.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search products, designs, ready-made…',
            border: InputBorder.none,
            suffixIcon: _isSearching
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category filter ──
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _filterChip('All', null),
                for (final d in ProductCatalog.categoryDescriptors)
                  _filterChip(d.name, d.name),
              ],
            ),
          ),
          Expanded(
            child: !_isSearching
                ? const _SearchPrompt()
                : !_hasResults
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No results for "$_q"',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try a different product, design or category.',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_matchingCategories.isNotEmpty)
                              _Section(
                                label: 'Categories',
                                icon: Icons.category_outlined,
                                child: _CategoryChips(
                                    categories: _matchingCategories,
                                    onTap: (c) {
                                      ProductCategory? descriptor;
                                      for (final d
                                          in ProductCatalog.categoryDescriptors) {
                                        if (d.name == c) {
                                          descriptor = d;
                                          break;
                                        }
                                      }
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              CategoryCatalogueScreen(
                                            category: descriptor ??
                                                ProductCategory(
                                                  id: c.toLowerCase(),
                                                  name: c,
                                                  imagePath: '',
                                                  tagline: '',
                                                  description: '',
                                                ),
                                          ),
                                        ),
                                      );
                                    }),
                              ),
                            if (_plainResults.isNotEmpty)
                              _Section(
                                label: 'Plain Products',
                                icon: Icons.checkroom,
                                child: _Grid(
                                  products: _plainResults,
                                  onTap: (p) => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProductDetailScreen(product: p),
                                    ),
                                  ),
                                ),
                              ),
                            if (_designResults.isNotEmpty)
                              _Section(
                                label: 'Designs',
                                icon: Icons.palette_outlined,
                                child: _DesignGrid(
                                  products: _designResults,
                                  onTap: (p) => _openDesignWithProduct(p),
                                  onCustomize: _openDesignWithProduct,
                                ),
                              ),
                            if (_readyMadeResults.isNotEmpty)
                              _Section(
                                label: 'Ready-Made',
                                icon: Icons.check_circle_outline,
                                child: _Grid(
                                  products: _readyMadeResults,
                                  onTap: (p) => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProductDetailScreen(product: p),
                                    ),
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

  Widget _filterChip(String label, String? value) {
    final selected = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _categoryFilter = value),
      ),
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Search the full catalogue',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text('Find plain products, designs and ready-made items',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;
  const _Section(
      {required this.label, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF6C5CE7)),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final void Function(String) onTap;
  const _CategoryChips({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categories)
          ActionChip(
            label: Text(c),
            onPressed: () => onTap(c),
            avatar: const Icon(Icons.category, size: 16),
          ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  final List<Product> products;
  final void Function(Product) onTap;
  const _Grid({required this.products, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 600 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxisCount >= 4 ? 0.78 : 0.72,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => ProductCard(
            product: products[index],
            onTap: () => onTap(products[index]),
          ),
        );
      },
    );
  }
}

class _DesignGrid extends StatelessWidget {
  final List<Product> products;
  final void Function(Product) onTap;
  final void Function(Product) onCustomize;
  const _DesignGrid(
      {required this.products,
      required this.onTap,
      required this.onCustomize});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 600 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxisCount >= 4 ? 0.72 : 0.68,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => DesignCard(
            product: products[index],
            onTap: () => onTap(products[index]),
            onCustomize: () => onCustomize(products[index]),
          ),
        );
      },
    );
  }
}
