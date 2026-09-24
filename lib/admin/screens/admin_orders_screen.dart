import 'package:flutter/material.dart';
import '../../frontend/models/order_item.dart';
import '../services/admin_service.dart';
import 'admin_order_detail_screen.dart';

/// Admin Orders — a professional, responsive list of all customer orders.
///
/// Renders a wide table layout on desktop/web and card tiles on narrow
/// screens. Tapping an order opens the detail screen.
class AdminOrdersScreen extends StatefulWidget {
  final Stream<List<OrderItem>> ordersStream;
  final AdminService adminService;
  final VoidCallback onRetry;

  const AdminOrdersScreen({
    super.key,
    required this.ordersStream,
    required this.adminService,
    required this.onRetry,
  });

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Orders',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              _StatusFilterBar(
                current: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<OrderItem>>(
            stream: widget.ordersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Could not load orders.',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              var orders = snapshot.data ?? [];
              if (_filter != 'All') {
                orders =
                    orders.where((o) => o.status == _filter).toList();
              }

              if (orders.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _filter == 'All'
                              ? 'No orders yet'
                              : 'No $_filter orders',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
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

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  if (isWide) {
                    return _OrdersTable(
                      orders: orders,
                      onOpen: (order) => _openDetail(context, order),
                    );
                  }
                  return _OrdersList(
                    orders: orders,
                    onOpen: (order) => _openDetail(context, order),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, OrderItem order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminOrderDetailScreen(
          order: order,
          adminService: widget.adminService,
        ),
      ),
    );
  }
}

/// Horizontal chip filter: All + each order status.
class _StatusFilterBar extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  static const _statuses = [
    'All',
    'Pending',
    'Confirmed',
    'Printing',
    'Shipped',
    'Delivered',
    'Cancelled',
  ];

  const _StatusFilterBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _statuses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = _statuses[index];
          final selected = current == s;
          return ChoiceChip(
            label: Text(s),
            selected: selected,
            onSelected: (_) => onChanged(s),
            selectedColor: const Color(0xFF6C5CE7),
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

/// Desktop/tablet table layout.
class _OrdersTable extends StatelessWidget {
  final List<OrderItem> orders;
  final ValueChanged<OrderItem> onOpen;

  const _OrdersTable({required this.orders, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 900),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              const Color(0xFF6C5CE7).withValues(alpha: 0.08),
            ),
            columns: const [
              DataColumn(label: Text('Order ID')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Items')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Payment')),
              DataColumn(label: Text('Status')),
            ],
            rows: orders.map((order) {
              return DataRow(
                onSelectChanged: (_) => onOpen(order),
                cells: [
                  DataCell(
                    Text(
                      order.orderId,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(
                    Text(_customerName(order),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  DataCell(Text(_formatDate(order.orderDate))),
                  DataCell(Text('${order.items.length} item(s)')),
                  DataCell(
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                  DataCell(_PaymentChip(order: order)),
                  DataCell(_StatusChip(status: order.status)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static String _customerName(OrderItem o) {
    final a = o.shippingAddress;
    if (a != null && a.fullName.isNotEmpty) return a.fullName;
    return 'Customer';
  }
}

/// Narrow-screen card list.
class _OrdersList extends StatelessWidget {
  final List<OrderItem> orders;
  final ValueChanged<OrderItem> onOpen;

  const _OrdersList({required this.orders, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final customer = _OrdersTable._customerName(order);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onOpen(order),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          order.orderId,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _StatusChip(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    customer,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(order.orderDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${order.items.length} item(s) • ${order.paymentMethod}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      _PaymentChip(order: order),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small coloured chip for a fulfilment status.
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
        return Colors.blue;
      case 'Printing':
        return Colors.purple;
      case 'Shipped':
        return Colors.teal;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Chip rendering the payment state: Pending / Paid / Failed / COD.
class _PaymentChip extends StatelessWidget {
  final OrderItem order;
  const _PaymentChip({required this.order});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _paymentLabel();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  (String, Color) _paymentLabel() {
    final method = order.paymentMethod.toLowerCase();
    if (method.contains('cash')) {
      return (
        'COD',
        Colors.amber.shade800,
      );
    }
    switch (order.paymentStatus) {
      case PaymentStatus.paid:
        return (
          'Paid',
          Colors.green,
        );
      case PaymentStatus.pending:
        return (
          'Payment Pending',
          Colors.orange,
        );
      default:
        return (
          'Pending',
          Colors.grey,
        );
    }
  }
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month
        .toString().padLeft(2, '0')}/${d.year}';

String _formatDateTime(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month
        .toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
