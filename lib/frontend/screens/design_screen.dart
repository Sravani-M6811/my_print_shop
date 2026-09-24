import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_catalog.dart';
import '../models/design.dart';
import '../models/product.dart';
import '../models/product_subcategory.dart';
import '../models/product_variant.dart';
import '../providers/app_state.dart';
import '../services/pexels_service.dart';
import '../../ui/widgets/design_card.dart';
import '../../ui/widgets/catalogue_image.dart';
import 'design_customize_screen.dart';
import 'plain_product_picker_screen.dart';
import 'product_list_screen.dart';
import 'subcategory_catalogue_screen.dart';
import 'variant_selection_screen.dart';

/// The main "Choose Your Design" gallery.
///
/// Two modes:
///   A. **With base product** — narrowed gallery for a specific plain product.
///   B. **With initialCategory only** — category-scoped gallery showing only
///      designs relevant to that category, grouped by design type.
///   C. **Without either** — full catalogue gallery (fallback).
///
/// Cards are driven by the reusable [Product] model so adding 100+ designs
/// later requires only new data records.
class DesignScreen extends StatefulWidget {
  final String initialCategory;

  /// When a plain/base product is selected from the Home "Start With a Product"
  /// flow, the gallery is narrowed to that product's category so the customer
  /// picks a design for their chosen base. Null shows the full catalogue.
  final Product? baseProduct;

  /// The label of the colour/variant chosen for [baseProduct] (e.g. "Red",
  /// "Matte", "Clear"). Shown on the base-product banner and carried into
  /// Customize -> Cart -> Order.
  final String? selectedVariant;

  /// The size chosen for [baseProduct] (e.g. 'L', 'XL'), when the product has
  /// sizes. Preserved through Customize -> Preview -> Cart so the configured
  /// variant is never lost.
  final String? selectedSize;

  /// Called when the user changes the colour/variant from the banner's
  /// "Change" action so the owning shell can keep the selection in sync.
  final ValueChanged<String>? onVariantChanged;

  /// The quantity chosen on the product detail screen. Preserved through to the
  /// customize/preview stages so the configured quantity is never lost.
  final int quantity;

  const DesignScreen({
    super.key,
    this.initialCategory = '',
    this.baseProduct,
    this.selectedVariant,
    this.selectedSize,
    this.onVariantChanged,
    this.quantity = 1,
  });

  @override
  State<DesignScreen> createState() => _DesignScreenState();
}

class _DesignScreenState extends State<DesignScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _typeFilter;

  /// The selected reusable design theme (Floral, Mandala, ...). Null shows
  /// every theme. Drill-down is data-driven via [ProductCatalog.themesForDesign].
  String? _themeFilter;

  /// The design currently selected for the chosen base product, shown with a
  /// highlighted selected state. Preserved so "Continue to Customize" carries
  /// both the base product and the chosen design.
  Product? _selectedDesign;

  /// The colour/variant label chosen for [widget.baseProduct]. Mirrored into
  /// local state so "Change" can update the banner even when this screen is a
  /// pushed route (no owning shell to notify).
  late String? _selectedVariant;

  final PexelsService _pexels = PexelsService.instance;
  Timer? _searchDebounce;
  int _pexelsGeneration = 0;
  List<PexelsImage> _pexelsImages = const [];
  bool _pexelsLoading = false;
  bool _pexelsSearched = false;
  String? _pexelsError;

  /// True when a Pexels key was provided at build time (or a test client was
  /// injected), so the search can back local results with network images.
  bool get _pexelsAvailable => _pexels.isConfigured;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.selectedVariant;
  }

  /// The effective category for this screen: the base product's category
  /// (highest priority) or the initial category passed from the category flow.
  String get _activeCategory =>
      widget.baseProduct?.category ?? widget.initialCategory;

  void _openCustomize(BuildContext context, Product? product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: Provider.of<AppState>(context, listen: false),
          child: DesignCustomizeScreen(
            product: product,
            baseProduct: widget.baseProduct,
            selectedVariant: _selectedVariant,
            selectedSize: widget.selectedSize,
            quantity: widget.quantity,
            title: product == null ? 'Upload Your Design' : 'Customize Design',
          ),
        ),
      ),
    );
  }

  /// Re-opens the colour/variant picker for the selected base product and
  /// reports a new choice back to the owning shell.
  Future<void> _changeVariant() async {
    final base = widget.baseProduct;
    if (base == null) return;
    final variant = await Navigator.of(context).push<ProductVariant>(
      MaterialPageRoute(
        builder: (_) => VariantSelectionScreen(
          baseProduct: base,
          initialVariant: _selectedVariant,
        ),
      ),
    );
    if (variant != null && mounted) {
      setState(() => _selectedVariant = variant.label);
      widget.onVariantChanged?.call(variant.label);
    }
  }

  /// True when the selected variant (or the base product's default option) is
  /// a real colour; used for the "Color:" vs "Option:" banner label.
  bool get _hasColorVariant {
    final base = widget.baseProduct;
    if (base == null) return false;
    return ProductCatalog.variantFor(base, _selectedVariant)?.isColor == true;
  }

  bool get _isSearching => _query.trim().isNotEmpty;
  bool get _hasBaseProduct => widget.baseProduct != null;

  @override
  void didUpdateWidget(DesignScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the base product changes, clear stale state.
    if (oldWidget.baseProduct?.id != widget.baseProduct?.id) {
      _searchDebounce?.cancel();
      _searchController.clear();
      _query = '';
      _typeFilter = null;
      _themeFilter = null;
      _categoryFilter = null;
      _subcategoryId = null;
      _selectedDesign = null;
      _selectedVariant = widget.selectedVariant;
      _pexelsGeneration++;
      _pexelsImages = const [];
      _pexelsLoading = false;
      _pexelsSearched = false;
      _pexelsError = null;
    } else if (oldWidget.selectedVariant != widget.selectedVariant) {
      _selectedVariant = widget.selectedVariant;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String get _searchHint {
    if (_hasBaseProduct) {
      return 'Search ${widget.baseProduct!.category} designs…';
    }
    if (_activeCategory.isEmpty) {
      return 'Search all designs…';
    }
    return 'Search $_activeCategory designs…';
  }

  String get _appBarTitle {
    if (_hasBaseProduct) {
      return 'Choose a Design for Your ${_baseLabel(widget.baseProduct!)}';
    }
    if (_activeCategory.isEmpty) {
      return 'All Designs';
    }
    return '$_activeCategory Designs';
  }

  /// The selected category filter for the *global* gallery. Null shows every
  /// category ("All"). Only meaningful when there is no base product and
  /// [_activeCategory] is empty; category-scoped galleries ignore it.
  String? _categoryFilter;

  /// The selected sub-category (stable [ProductSubcategory.id]) for the global
  /// gallery when a category chip is set. Refines the category's designType
  /// sections (design-driven sub-categories) or links to the plain-product
  /// sub-category screen (alias-based sub-categories).
  String? _subcategoryId;

  @override
  Widget build(BuildContext context) {
    final base = widget.baseProduct;
    final AppBar appBar = AppBar(
      title: Text(
        _appBarTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
      ),
    );

    return Scaffold(
      appBar: appBar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
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

          // ── Theme filters (design library browse) ──
          if (!_isSearching) _buildThemeFilterRow(context),

          Expanded(
            child: _isSearching
                ? _buildSearchResults(context)
                : (base != null
                    ? _buildBaseProductGallery(context)
                    : _buildCategoryGallery(context)),
          ),
        ],
      ),
    );
  }

  /// Strips a leading "Plain " so the header reads naturally.
  static String _baseLabel(Product base) =>
      base.name.startsWith('Plain ') ? base.name.substring(6) : base.name;

  // ─── Search Results ─────────────────────────────────────────────────────

  /// Search results scoped to the active category (or the whole design
  /// catalogue in global mode), topped up with a live Pexels section when
  /// configured.
  Widget _buildSearchResults(BuildContext context) {
    final results = _activeCategory.isEmpty
        ? ProductCatalog.filteredSearch(_query)
            .where((p) => p.isDesign)
            .toList()
        : ProductCatalog.filteredSearch(_query, category: _activeCategory);
    final pexelsVisible = _pexelsAvailable && _pexelsSearched;

    // Nothing local and no Pexels section -> keep the full-screen empty state.
    if (results.isEmpty && !pexelsVisible) {
      return _buildNoLocalResults(context);
    }

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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.search_off,
                        size: 20, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _activeCategory.isEmpty
                            ? 'No designs match "${_query.trim()}".'
                            : 'No designs in $_activeCategory match '
                                '"${_query.trim()}".',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8),
                child: Text(
                  '${results.length} '
                  'design${results.length == 1 ? '' : 's'} found',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700),
                ),
              ),
            if (results.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: columns >= 4 ? 0.72 : 0.68,
                ),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final product = results[index];
                  return DesignCard(
                    product: product,
                    onTap: () => _openCustomize(context, product),
                    onCustomize: () => _openCustomize(context, product),
                  );
                },
              ),
            _buildPexelsSection(context),
          ],
        );
      },
    );
  }

  /// The original media-less empty state for a search that has no local results
  /// and no Pexels section to show.
  Widget _buildNoLocalResults(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No designs found for "${_query.trim()}"',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _activeCategory.isEmpty
                  ? 'Try a different keyword.'
                  : 'Try a different keyword in $_activeCategory designs.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    if (!_pexelsAvailable || value.trim().isEmpty) {
      _pexelsGeneration++;
      setState(() {
        _pexelsImages = const [];
        _pexelsLoading = false;
        _pexelsSearched = false;
        _pexelsError = null;
      });
      return;
    }
    final category = _activeCategory;
    setState(() {
      _pexelsLoading = true;
      _pexelsError = null;
      _pexelsSearched = true;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _runPexelsSearch(category, value.trim()),
    );
  }

  Future<void> _runPexelsSearch(String category, String query) async {
    final generation = ++_pexelsGeneration;
    try {
      final images = await _pexels.search(category: category, query: query);
      if (!mounted || generation != _pexelsGeneration) return;
      setState(() {
        _pexelsImages = images;
        _pexelsLoading = false;
        _pexelsError = null;
      });
    } on PexelsException catch (e) {
      if (!mounted || generation != _pexelsGeneration) return;
      setState(() {
        _pexelsLoading = false;
        _pexelsError = e.message;
      });
    }
  }

  void _retryPexelsSearch() {
    if (_query.trim().isEmpty) return;
    setState(() {
      _pexelsLoading = true;
      _pexelsError = null;
    });
    _runPexelsSearch(_activeCategory, _query.trim());
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _pexelsGeneration++;
    _searchController.clear();
    setState(() {
      _query = '';
      _pexelsImages = const [];
      _pexelsLoading = false;
      _pexelsSearched = false;
      _pexelsError = null;
    });
  }

  Widget _buildPexelsSection(BuildContext context) {
    if (!_pexelsAvailable || !_pexelsSearched) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pexels Inspiration',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800),
              ),
              const SizedBox(width: 8),
              if (!_pexelsLoading && _pexelsError == null)
                Text(
                  '${_pexelsImages.length} '
                  'image${_pexelsImages.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_pexelsLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Searching Pexels for "${_query.trim()}"…',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            )
          else if (_pexelsError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFE57373).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off,
                      size: 18, color: Color(0xFFE57373)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pexelsError!,
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _retryPexelsSearch,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_pexelsImages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No Pexels images found for "${_query.trim()}".',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pexelsImages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final image = _pexelsImages[index];
                  return _PexelsDesignCard(
                    image: image,
                    onTap: () => _openPexelsDesign(context, image),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _openPexelsDesign(BuildContext context, PexelsImage image) {
    // In global mode there is no single category; prefer the category filter the
    // customer is browsing, falling back to the store's flagship category.
    final category = _activeCategory.isNotEmpty
        ? _activeCategory
        : (_categoryFilter ?? 'T-Shirts');
    final categoryDesigns = ProductCatalog.productsForCategory(category);
    final design = Product(
      id: 'pexels_${image.id}',
      name: image.alt.isEmpty ? '$category design' : image.alt,
      category: category,
      description: 'Pexels design by ${image.photographer}. Printed by MY '
          'PRINT SHOP on your $category.',
      basePrice:
          categoryDesigns.isNotEmpty ? categoryDesigns.first.basePrice : 499.0,
      imagePath: image.url,
      tags: [category.toLowerCase()],
      keywords: const [],
    );
    _openCustomize(context, design);
  }

  // ─── Base Product Gallery (narrowed to a selected plain product) ──────

  Widget _buildBaseProductGallery(BuildContext context) {
    final base = widget.baseProduct!;
    final designs = _byTheme(ProductCatalog.designsForBase(base));
    final trending =
        _byTheme(ProductCatalog.trendingProducts(category: base.category));
    final visibleDesigns = _typeFilter == null
        ? designs
        : designs.where((p) => p.designType == _typeFilter).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Base product banner ──
          _buildBaseBanner(base),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose a Design',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800)),
                const SizedBox(height: 2),
                Text('For ${base.name}',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),

          // ── Upload Your Own ──
          _buildUploadCard(context, base.category),

          if (visibleDesigns.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _themeFilter != null
                    ? 'No "$_themeFilter" themed designs for '
                        '${base.category} yet.'
                    : _typeFilter == null
                        ? 'New designs coming soon for ${base.category}.'
                        : 'No "$_typeFilter" designs for ${base.category} yet.',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else ...[
            // Selectable grid of matching designs only.
            _DesignGrid(
              products: visibleDesigns,
              selectedId: _selectedDesign?.id,
              onSelect: (p) => setState(() => _selectedDesign = p),
            ),

            // Selected-state summary + Continue to Customize.
            const SizedBox(height: 12),
            if (_selectedDesign != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            const Color(0xFF6C5CE7).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Selection',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C5CE7))),
                      const SizedBox(height: 6),
                      _SelectionRow(label: 'Product', value: base.name),
                      _SelectionRow(
                          label: 'Design', value: _selectedDesign!.name),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    _selectedDesign == null
                        ? 'Select a Design to Continue'
                        : 'Continue to Customize',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _selectedDesign == null
                      ? null
                      : () => _openCustomize(context, _selectedDesign),
                ),
              ),
            ),
          ],
          if (trending.isNotEmpty)
            _CategorySection(
              title: 'Trending ${base.category}',
              products: trending,
              onViewAll: () =>
                  _openCustomize(context, trending.first),
              onDesignTap: (p) => _openCustomize(context, p),
              onApplyToProduct: (p) =>
                  _openPlainProductPicker(context, p),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text('Browse by Type',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                _typeChip('All', null),
                for (final t
                    in ProductCatalog.designTypesForCategory(base.category))
                  _typeChip(t, t),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Category Gallery (when initialCategory is set, no base product) ─

  /// A category-scoped gallery that shows only the selected category's
  /// designs, grouped by design type with horizontal carousels.
  Widget _buildCategoryGallery(BuildContext context) {
    final cat = _activeCategory;

    // If no category is set, fall back to the global gallery.
    if (cat.isEmpty) return _buildGlobalGallery(context);

    // Single source of truth: the category's available designs (normalized
    // labels, availability-filtered, theme-filtered) grouped by design type,
    // with any un-typed remainder always surfaced — a design in the catalogue
    // can never silently disappear from its category gallery again.
    final categoryDesigns = ProductCatalog.customerDesigns(
        category: cat, theme: _themeFilter);
    final trending = _byTheme(ProductCatalog.trendingProducts(category: cat));
    final designTypes = ProductCatalog.designTypesForCategory(cat);

    final sections = [
      for (final group in ProductCatalog.groupDesignsByType(categoryDesigns))
        _DesignSection(title: group.title, products: group.products),
    ];

    // Find the category descriptor for the banner image.
    final descriptor = ProductCatalog.categoryDescriptors
        .where((d) => d.name == cat)
        .firstOrNull;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category banner ──
          if (descriptor != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                        imagePath: descriptor.imagePath,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$cat Designs',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            descriptor.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${categoryDesigns.length} designs available',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ── Upload card ──
          _buildUploadCard(context, cat),

          // ── Design type sections ──
          for (final section in sections)
            _CategorySection(
              title: section.title,
              products: section.products,
              showViewAll: false,
              onViewAll: () {},
              onDesignTap: (p) => _openCustomize(context, p),
              onApplyToProduct: (p) =>
                  _openPlainProductPicker(context, p),
            ),

          // ── Empty state when theme filters exclude every design ──
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.filter_alt_off_outlined,
                      size: 44, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(
                    _themeFilter != null
                        ? 'No "$_themeFilter" themed designs for $cat yet.'
                        : 'New designs coming soon for $cat.',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          // ── Trending ──
          if (trending.isNotEmpty)
            _CategorySection(
              title: 'Trending $cat Designs',
              products: trending,
              onViewAll: () =>
                  _openCustomize(context, trending.first),
              onDesignTap: (p) => _openCustomize(context, p),
              onApplyToProduct: (p) =>
                  _openPlainProductPicker(context, p),
            ),

          // ── Browse by type chips ──
          if (designTypes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Browse by Type',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600)),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  _typeChip('All', null),
                  for (final t in designTypes) _typeChip(t, t),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Global Gallery (fallback, no category set) ──────────────────────

  Widget _buildGlobalGallery(BuildContext context) {
    final allCategories = ProductCatalog.categories;
    final categories = _categoryFilter == null
        ? allCategories
        : [for (final c in allCategories) if (c == _categoryFilter) c];
    final trending = ProductCatalog.trendingProducts();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── No product selected warning ──
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFFF57C00), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Choose a product first',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE65100)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Browse designs for inspiration, then select a plain product to start customizing.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.shopping_bag, size: 18),
                    label: const Text('Choose a Product to Start',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // ── Design Inspiration ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Design Inspiration',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700)),
          ),

          // ── Trending designs (global) ──
          trending.isNotEmpty
              ? _CategorySection(
                  title: 'Trending Now',
                  products: trending,
                  onViewAll: () =>
                      _openCustomize(context, trending.first),
                  onDesignTap: (p) => _openCustomize(context, p),
                  onApplyToProduct: (p) =>
                      _openPlainProductPicker(context, p),
                )
              : const SizedBox.shrink(),

          // ── Browse by category (reusable design collection) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Browse by Category',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _categoryChip('All', null),
                for (final c in allCategories) _categoryChip(c, c),
              ],
            ),
          ),

          // ── Browse by design type (reusable design collection) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Browse by Type',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _typeChip('All', null),
                for (final t in ProductCatalog.allDesignTypes)
                  _typeChip(t, t),
              ],
            ),
          ),

          // ── Browse by sub-category (refines the selected category) ──
          if (_categoryFilter != null)
            _buildSubcategoryRow(),

          // ── Upload Your Design ──
          _buildUploadCard(context, ''),

          const SizedBox(height: 4),

          // ── Category-wise gallery ──
          ..._buildGlobalGallerySections(
            context,
            categories: categories,
            allCategories: allCategories,
          ),
        ],
      ),
    );
  }

  // ─── Shared widgets ──────────────────────────────────────────────────

  Widget _buildBaseBanner(Product base) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                imagePath: base.imagePath,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    base.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    base.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'From ₹${base.basePrice.toInt()} · Pick a design below',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        _hasColorVariant
                            ? Icons.color_lens_outlined
                            : Icons.tune,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${_hasColorVariant ? 'Color' : 'Option'}: '
                          '${_selectedVariant ?? '—'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _changeVariant,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Change',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.selectedSize != null &&
                      widget.selectedSize!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.straighten,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Size: ${widget.selectedSize}',
                          style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.9),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(BuildContext context, String category) {
    final label = category.isEmpty
        ? ''
        : ' on your ${category.toLowerCase().replaceAllMapped(
            RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase())}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openCustomize(context, null),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF6C5CE7), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.upload_file,
                      color: Color(0xFF6C5CE7), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Upload Your Design',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 3),
                      Text(
                        category.isEmpty
                            ? 'Bring your own artwork or logo — we print it for you.'
                            : 'Bring your own artwork or logo — we print it$label.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF6C5CE7)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The designs for [category], filtered by the selected design type/theme via
  /// the central catalogue query — the single source of truth for every
  /// customer design filter.
  List<Product> _sectionDesigns(String category) =>
      ProductCatalog.customerDesigns(
          category: category, designType: _typeFilter, theme: _themeFilter);

  Widget _typeChip(String label, String? value) {
    final selected = _typeFilter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _typeFilter = value),
      ),
    );
  }

  /// Category filter chip for the *global* gallery. Tapping a category narrows
  /// the gallery sections to that category only; tapping it again (or "All")
  /// clears the filter. Changing the category resets any sub-category filter.
  Widget _categoryChip(String label, String? value) {
    final selected = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() {
          _categoryFilter = value == _categoryFilter ? null : value;
          _subcategoryId = null;
        }),
      ),
    );
  }

  /// Sub-category filter chips for the *global* gallery. Only rendered when a
  /// category is selected. Design-driven sub-categories (e.g. Embroidery →
  /// "Floral") refine the gallery sections by [ProductSubcategory.designType];
  /// alias-based sub-categories that only group plain products render a
  /// cross-link card to the dedicated sub-category screen.
  Widget _buildSubcategoryRow() {
    final subs = ProductCatalog.subcategoriesFor(_categoryFilter!);
    if (subs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('Browse by Subcategory',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600)),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            key: const ValueKey('design-subcategory-filters'),
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              _subcategoryChip('All', null),
              for (final s in subs) _subcategoryChip(s.name, s.id),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subcategoryChip(String label, String? value) {
    final selected = _subcategoryId == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() {
          _subcategoryId = value == _subcategoryId ? null : value;
        }),
      ),
    );
  }

  /// Builds the gallery sections under the global gallery. When a sub-category
  /// is active only that sub-category's section is shown; otherwise one section
  /// per filtered category is rendered.
  List<Widget> _buildGlobalGallerySections(
    BuildContext context, {
    required List<String> categories,
    required List<String> allCategories,
  }) {
    if (_subcategoryId != null) {
      final sub = ProductCatalog.subcategoryById(_subcategoryId!);
      if (sub != null && _categoryFilter != null) {
        final type = sub.designType;
        if (type != null && type.isNotEmpty) {
          final products = ProductCatalog.customerDesigns(
              category: _categoryFilter!,
              designType: type,
              theme: _themeFilter,
              includeReadyMade: true);
          if (products.isEmpty) {
            return [
              _SubcategoryCrossLinkCard(
                subcategory: sub,
                category: _categoryFilter!,
                hint: 'No designs for this sub-category yet.',
              ),
            ];
          }
          return [
            _CategorySection(
              title: '${sub.name} Designs',
              products: products,
              onViewAll: () {},
              onDesignTap: (p) => _openCustomize(context, p),
              onApplyToProduct: (p) => _openPlainProductPicker(context, p),
              showViewAll: false,
            ),
          ];
        }
        return [
          _SubcategoryCrossLinkCard(
            subcategory: sub,
            category: _categoryFilter!,
            hint: 'Browse the plain products in this sub-category.',
          ),
        ];
      }
    }
    return [
      for (final category in categories)
        _CategorySection(
          title: category,
          products: _sectionDesigns(category),
          onViewAll: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductListScreen(category: category),
            ),
          ),
          onDesignTap: (p) => _openCustomize(context, p),
          onApplyToProduct: (p) => _openPlainProductPicker(context, p),
        ),
    ];
  }

  /// The selectable design theme chips (Floral, Mandala, ...) shown at the top
  /// of the gallery so the customer can filter the design library by what the
  /// artwork looks like. Data-driven from [ProductCatalog.designThemes].
  Widget _buildThemeFilterRow(BuildContext context) {
    final themes = ProductCatalog.designThemes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Text(
            'Browse by Theme',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            key: const ValueKey('design-theme-filters'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              _themeChip('All', null),
              for (final t in themes) _themeChip(t, t),
            ],
          ),
        ),
      ],
    );
  }

  Widget _themeChip(String label, String? value) {
    final selected = _themeFilter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _themeFilter = value),
      ),
    );
  }

  /// Filters a design list by the selected theme. Derived from the design's
  /// tags via [ProductCatalog.themesForDesign]; null theme returns the input.
  List<Product> _byTheme(List<Product> designs) {
    if (_themeFilter == null) return designs;
    return designs
        .where((p) => ProductCatalog
            .themesForDesign(ProductCatalog.enrichedDesign(Design.fromProduct(p)))
            .contains(_themeFilter))
        .toList();
  }

  void _openPlainProductPicker(BuildContext context, Product design) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlainProductPickerScreen(design: design),
      ),
    );
  }
}

// ─── Internal data class for grouped sections ──────────────────────────

class _DesignSection {
  final String title;
  final List<Product> products;
  const _DesignSection({required this.title, required this.products});
}

// ─── Category Section (horizontal carousel) ───────────────────────────

class _CategorySection extends StatelessWidget {
  final String title;
  final List<Product> products;
  final VoidCallback onViewAll;
  final void Function(Product) onDesignTap;
  final void Function(Product)? onApplyToProduct;

  /// When false, the "View All" affordance is hidden. Used in the category-
  /// scoped gallery where every design of a section is already shown.
  final bool showViewAll;

  const _CategorySection({
    required this.title,
    required this.products,
    required this.onViewAll,
    required this.onDesignTap,
    this.onApplyToProduct,
    this.showViewAll = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (products.isNotEmpty && showViewAll)
                  GestureDetector(
                    onTap: onViewAll,
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'New designs coming soon.',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            // Horizontal carousel; bounded height so the page scrolls vertically.
            SizedBox(
              height: 235,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return SizedBox(
                    width: 160,
                    child: DesignCard(
                      product: product,
                      onTap: () => onDesignTap(product),
                      onCustomize: () => onDesignTap(product),
                      onApplyToProduct: onApplyToProduct == null
                          ? null
                          : () => onApplyToProduct!(product),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Pexels Design Card ────────────────────────────────────────────────

/// A network-backed inspiration card from a live Pexels search. Tapping it
/// builds a [Product] carrying the photo URL so the customer can carry the
/// image through Customize -> Preview -> Cart like any local design.
class _PexelsDesignCard extends StatelessWidget {
  final PexelsImage image;
  final VoidCallback onTap;

  const _PexelsDesignCard({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: SizedBox(
          width: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Image.network(
                  image.url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : Container(
                              color: Theme.of(context).colorScheme.outlineVariant,
                              child: const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                  errorBuilder: (_, _, _) => Container(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    child: const Icon(Icons.broken_image_outlined, size: 36),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        image.alt.isEmpty ? 'Design' : image.alt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        image.photographer.isEmpty
                            ? 'Pexels'
                            : image.photographer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      Text(
                        'Use this design',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6C5CE7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Selectable Design Grid (used in base product gallery) ────────────

class _DesignGrid extends StatelessWidget {
  final List<Product> products;
  final String? selectedId;
  final void Function(Product) onSelect;

  const _DesignGrid({
    required this.products,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 5
            : width >= 900
                ? 4
                : width >= 600
                    ? 3
                    : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                crossAxisCount >= 4 ? 0.72 : 0.7,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final selected = product.id == selectedId;
            return _SelectableDesignCard(
              product: product,
              selected: selected,
              onTap: () => onSelect(product),
            );
          },
        );
      },
    );
  }
}

// ─── Selectable Design Card ───────────────────────────────────────────

class _SelectableDesignCard extends StatelessWidget {
  final Product product;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableDesignCard({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: selected ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF6C5CE7)
                    : Theme.of(context).colorScheme.outlineVariant,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: CatalogueImage(
                    imagePath: product.imagePath,
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 30,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selected
                                  ? const Color(0xFF6C5CE7)
                                  : Colors.white,
                              foregroundColor: selected
                                  ? Colors.white
                                  : const Color(0xFF6C5CE7),
                              side: const BorderSide(
                                  color: Color(0xFF6C5CE7),
                                  width: 1),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            onPressed: onTap,
                            child: Text(
                                selected ? 'Selected' : 'Select'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF6C5CE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Selection Row ────────────────────────────────────────────────────

class _SelectionRow extends StatelessWidget {
  final String label;
  final String value;
  const _SelectionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-category cross-link card ──────────────────────────────────────

/// Shown in the global design gallery when the active sub-category has no
/// design records of its own (alias-based sub-categories that group plain
/// products). Links the customer to the dedicated sub-category screen instead
/// of showing an empty gallery.
class _SubcategoryCrossLinkCard extends StatelessWidget {
  final ProductSubcategory subcategory;
  final String category;
  final String hint;

  const _SubcategoryCrossLinkCard({
    required this.subcategory,
    required this.category,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subcategory.tagline.isNotEmpty
                          ? subcategory.tagline
                          : subcategory.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hint,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubcategoryCatalogueScreen(
                      subcategory: subcategory,
                      category: category,
                    ),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Browse'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
