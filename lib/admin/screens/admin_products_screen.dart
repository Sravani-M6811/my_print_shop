import 'package:flutter/material.dart';

import '../../frontend/data/product_catalog.dart';
import '../../frontend/models/product.dart';
import '../services/catalogue_service.dart';
import 'admin_product_form_screen.dart';

/// Admin Products — manage the store's catalogue products.
///
/// Lists the catalogue as a merged view (static catalogue + admin-managed
/// Firestore overrides), with search, category and availability filters.
/// Desktop/web render a professional table; narrow screens render responsive
/// cards with edit/delete actions.
class AdminProductsScreen extends StatefulWidget {
  final CatalogueRepository? repository;

  const AdminProductsScreen({super.key, this.repository});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  late CatalogueRepository _repository;
  late Future<List<Product>> _future;

  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';
  String _availability = 'All';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Product>> _load() async {
    _repository = widget.repository ?? CatalogueService();
    // Static-only base: the merged customer list would double-merge overrides.
    final base = ProductCatalog.staticProducts;
    final remote = await _repository.fetchProducts();
    return CatalogueService.mergeProducts(base, remote);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  List<Product> _filter(List<Product> all) {
    final query = _query.trim();
    return all.where((p) {
      if (query.isNotEmpty && !p.matches(query)) return false;
      if (_category != 'All' && p.category != _category) return false;
      if (_availability == 'Available' && !p.isAvailable) return false;
      if (_availability == 'Unavailable' && p.isAvailable) return false;
      return true;
    }).toList();
  }

  Future<void> _openAdd() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AdminProductFormScreen(repository: _repository),
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _openEdit(Product product) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminProductFormScreen(
          repository: _repository,
          product: product,
        ),
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'This will hide "${product.name}" from the storefront. '
          'Past orders are never affected. You can restore it later by editing '
          'the product and turning availability back on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _repository.deactivateProduct(product);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${product.name}" deleted from storefront.')),
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete product. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        _buildControls(),
        Expanded(
          child: FutureBuilder<List<Product>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ErrorState(onRetry: _reload);
              }
              final all = snapshot.data ?? const <Product>[];
              final filtered = _filter(all);
              if (filtered.isEmpty) {
                return _EmptyState(
                  onClear: () {
                    setState(() {
                      _query = '';
                      _searchController.clear();
                      _category = 'All';
                      _availability = 'All';
                    });
                  },
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  if (isWide) {
                    return _ProductsTable(
                      products: filtered,
                      onEdit: _openEdit,
                      onDelete: _confirmDelete,
                    );
                  }
                  return _ProductsCards(
                    products: filtered,
                    onEdit: _openEdit,
                    onDelete: _confirmDelete,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Products',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Catalogue management — add, edit and hide products.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _openAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Product'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          _FilterDropdown<String>(
            value: _category,
            label: 'Category',
            items: ['All', ...ProductCatalog.categories],
            onChanged: (v) => setState(() => _category = v!),
          ),
          _FilterDropdown<String>(
            value: _availability,
            label: 'Availability',
            items: const ['All', 'Available', 'Unavailable'],
            onChanged: (v) => setState(() => _availability = v!),
          ),
        ],
      ),
    );
  }
}

/// Wide-screen table of products.
class _ProductsTable extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  const _ProductsTable({
    required this.products,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1040),
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            const Color(0xFF6C5CE7).withValues(alpha: 0.08),
          ),
          columns: const [
            DataColumn(label: Text('Image')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Subcategory')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Price')),
            DataColumn(label: Text('Material / Size')),
            DataColumn(label: Text('Availability')),
            DataColumn(label: Text('Actions')),
          ],
          rows: products.map((p) {
            return DataRow(
              cells: [
                DataCell(_ProductThumb(imagePath: p.imagePath)),
                DataCell(FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 180,
                    child: Text(p.name,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                )),
                DataCell(FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(p.category),
                )),
                DataCell(FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(p.subcategory.isEmpty ? '—' : p.subcategory),
                )),
                DataCell(FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(_typeLabel(p)),
                )),
                DataCell(FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '₹${p.basePrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.green),
                  ),
                )),
                DataCell(FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 130,
                    child: Text(
                      p.material ?? (p.availableSizes.isEmpty
                          ? '—'
                          : p.availableSizes.join(', ')),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )),
                DataCell(FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _AvailabilityChip(available: p.isAvailable),
                )),
                DataCell(FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _RowActions(
                    onEdit: () => onEdit(p),
                    onDelete: () => onDelete(p),
                  ),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  static String _typeLabel(Product p) {
    if (p.isBase) return 'Base';
    if (p.isReadyMade) return 'Ready-made';
    return 'Design';
  }
}

/// Narrow-screen card list.
class _ProductsCards extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  const _ProductsCards({
    required this.products,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _ProductThumb(imagePath: p.imagePath, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        '${p.category} • ${_ProductsTable._typeLabel(p)}'
                        '${p.subcategory.isEmpty ? '' : ' • ${p.subcategory}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '₹${p.basePrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          _AvailabilityChip(available: p.isAvailable),
                        ],
                      ),
                      if (p.material != null || p.availableSizes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            (p.material ?? '').isNotEmpty
                                ? p.material!
                                : p.availableSizes.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ),
                    ],
                  ),
                ),
                _RowActions(
                  onEdit: () => onEdit(p),
                  onDelete: () => onDelete(p),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small rounded image thumbnail with a graceful fallback.
class _ProductThumb extends StatelessWidget {
  final String imagePath;
  final double size;

  const _ProductThumb({required this.imagePath, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final Widget image;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      image = Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _thumbFallback(context, size),
      );
    } else {
      image = Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _thumbFallback(context, size),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: image,
      ),
    );
  }

  Widget _thumbFallback(BuildContext context, double s) => Container(
        width: s,
        height: s,
        color: Theme.of(context).colorScheme.outlineVariant,
        child: Icon(Icons.image_not_supported_outlined,
            size: s * 0.5, color: Colors.grey.shade400),
      );
}

class _AvailabilityChip extends StatelessWidget {
  final bool available;
  const _AvailabilityChip({required this.available});

  @override
  Widget build(BuildContext context) {
    final color = available ? Colors.green : Colors.red.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        available ? 'Available' : 'Unavailable',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Edit / delete actions with vertical layout for cards, row layout for tables.
class _RowActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RowActions({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 20),
          color: const Color(0xFF6C5CE7),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 20),
          color: Colors.red.shade600,
        ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String label;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(10),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item, child: Text('$item')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onClear;
  const _EmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No products found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Try clearing the search or filters.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Could not load products.',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
