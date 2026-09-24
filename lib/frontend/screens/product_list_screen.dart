import 'package:flutter/material.dart';
import '../data/product_catalog.dart';
import '../models/product.dart';
import '../../ui/widgets/catalogue_image.dart';
import 'product_detail_screen.dart';

/// Category browse screen with two clearly separated tabs:
///
///   [Customize]  — plain/base products (customer picks a design)
///   [Ready-Made] — already printed products (buy directly)
///
/// This makes the business concept immediately understandable: customize
/// a plain product, or buy something already designed.
class ProductListScreen extends StatefulWidget {
  final String category;
  const ProductListScreen({super.key, required this.category});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plain = ProductCatalog.plainProductsForCategory(widget.category);
    final readyMade =
        ProductCatalog.readyMadeProductsForCategory(widget.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6C5CE7),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF6C5CE7),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Customize'),
                Tab(text: 'Ready-Made'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Customize tab: plain/base products ──
          plain.isEmpty
              ? _EmptyState(
                  icon: Icons.palette_outlined,
                  message: 'No plain ${widget.category.toLowerCase()} to customize yet',
                  subtitle: 'Check back soon!',
                )
              : _ProductGrid(
                  products: plain,
                  badge: 'Plain',
                  badgeColor: const Color(0xFF6C5CE7),
                  ctaLabel: 'Choose Product',
                  ctaColor: const Color(0xFF6C5CE7),
                ),

          // ── Ready-Made tab: already printed products ──
          readyMade.isEmpty
              ? _EmptyState(
                  icon: Icons.check_circle_outline,
                  message: 'No ready-made ${widget.category.toLowerCase()} yet',
                  subtitle: 'Check back soon!',
                )
              : _ProductGrid(
                  products: readyMade,
                  badge: 'Ready-Made',
                  badgeColor: Colors.green,
                  ctaLabel: 'View',
                  ctaColor: Colors.green,
                ),
        ],
      ),
    );
  }
}

// ─── Empty State ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  const _EmptyState({
    required this.icon,
    required this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Product Grid ───────────────────────────────────────────────────────────

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final String badge;
  final Color badgeColor;
  final String ctaLabel;
  final Color ctaColor;

  const _ProductGrid({
    required this.products,
    required this.badge,
    required this.badgeColor,
    required this.ctaLabel,
    required this.ctaColor,
  });

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
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _ProductCard(
              product: product,
              badge: badge,
              badgeColor: badgeColor,
              ctaLabel: ctaLabel,
              ctaColor: ctaColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: product),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Product Card ───────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final String badge;
  final Color badgeColor;
  final String ctaLabel;
  final Color ctaColor;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.badge,
    required this.badgeColor,
    required this.ctaLabel,
    required this.ctaColor,
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
                CatalogueImage(
                  imagePath: product.imagePath,
                  fit: BoxFit.cover,
                ),
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
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                            color: ctaColor,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ctaColor,
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
