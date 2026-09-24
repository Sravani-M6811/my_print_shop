import 'package:flutter/material.dart';
import '../../frontend/models/order_item.dart';
import '../services/admin_service.dart';

/// Admin Dashboard — aggregates live order data from the `allOrders`
/// Firestore collection into professional statistic cards.
class AdminDashboardScreen extends StatelessWidget {
  final Stream<List<OrderItem>> ordersStream;
  final AdminService adminService;
  final VoidCallback onRetry;

  const AdminDashboardScreen({
    super.key,
    required this.ordersStream,
    required this.adminService,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderItem>>(
      stream: ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorState(
            message: 'Could not load order data.',
            onRetry: onRetry,
          );
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics_outlined,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No orders yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Orders placed by customers will appear here.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        final stats = adminService.computeStats(orders);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live overview of all customer orders.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isWide) _wideLayout(stats) else _narrowLayout(stats),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Large screens: revenue hero + a grid of status cards.
  Widget _wideLayout(AdminStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RevenueCard(stats: stats),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.4,
          ),
          itemCount: _statusCards(stats).length,
          itemBuilder: (context, index) => _statusCards(stats)[index],
        ),
      ],
    );
  }

  /// Small screens: status cards stacked in a 2-column grid.
  Widget _narrowLayout(AdminStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RevenueCard(stats: stats),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.8,
          ),
          itemCount: _statusCards(stats).length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _TotalOrdersCard(stats: stats);
            return _statusCards(stats)[index - 1];
          },
        ),
      ],
    );
  }

  List<Widget> _statusCards(AdminStats stats) => [
        _StatusCard(
          label: 'Pending',
          value: stats.pending,
          icon: Icons.schedule,
          color: Colors.orange,
        ),
        _StatusCard(
          label: 'Confirmed',
          value: stats.confirmed,
          icon: Icons.verified,
          color: Colors.blue,
        ),
        _StatusCard(
          label: 'Printing',
          value: stats.printing,
          icon: Icons.print,
          color: Colors.purple,
        ),
        _StatusCard(
          label: 'Shipped',
          value: stats.shipped,
          icon: Icons.local_shipping,
          color: Colors.teal,
        ),
        _StatusCard(
          label: 'Delivered',
          value: stats.delivered,
          icon: Icons.inventory_2,
          color: Colors.green,
        ),
        _StatusCard(
          label: 'Cancelled',
          value: stats.cancelled,
          icon: Icons.cancel,
          color: Colors.red,
        ),
      ];
}

/// Revenue card shown on every layout.
class _RevenueCard extends StatelessWidget {
  final AdminStats stats;
  const _RevenueCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.currency_rupee, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Revenue',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Verified online payments received',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${stats.totalRevenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${stats.totalOrders} total orders',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Total orders card used in the narrow layout.
class _TotalOrdersCard extends StatelessWidget {
  final AdminStats stats;
  const _TotalOrdersCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _StatusCard(
      label: 'Total Orders',
      value: stats.totalOrders,
      icon: Icons.receipt_long,
      color: const Color(0xFF6C5CE7),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatusCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

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
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
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
