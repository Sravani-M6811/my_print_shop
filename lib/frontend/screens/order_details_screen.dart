import 'package:flutter/material.dart';
import '../constants/asset_paths.dart';
import '../models/order_item.dart';

class OrderDetailsScreen extends StatelessWidget {
  final OrderItem order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderId,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Placed on ${_formatDate(order.orderDate)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
                Chip(
                  label: Text(
                    order.status,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: const Color(0xFF6C5CE7),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payments_outlined, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  order.paymentMethod,
                  style: const TextStyle(fontSize: 14),
                ),
                if (order.paymentId != null && order.paymentId!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('• ID ${order.paymentId!}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.verified_outlined, size: 16,
                    color: Color(0xFF6C5CE7)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: order.paymentStatus == 'paid'
                        ? Colors.green.shade50
                        : order.paymentStatus == 'pending'
                            ? Colors.orange.shade50
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.paymentStatus == 'paid'
                        ? 'Payment Paid'
                        : order.paymentStatus == 'pending'
                            ? 'Payment Pending Verification'
                            : 'Pay on Delivery',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: order.paymentStatus == 'paid'
                          ? Colors.green.shade800
                          : order.paymentStatus == 'pending'
                              ? Colors.orange.shade800
                              : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Items
            const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...order.items.map((item) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            AssetPaths.productImageForCategory(item.category),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${item.category} ${item.quantity > 1 ? '× ${item.quantity}' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (item.baseProductTitle != null &&
                                  item.baseProductTitle!.isNotEmpty)
                                Text(
                                  'Base: ${item.baseProductTitle}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              if (item.selectedVariant != null &&
                                  item.selectedVariant!.isNotEmpty)
                                Text(
                                  'Variant: ${item.selectedVariant}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              if (item.size != null && item.size!.isNotEmpty)
                                Text(
                                  'Size: ${item.size}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              if (item.customText.isNotEmpty)
                                Text(
                                  '"${item.customText}" • ${item.fontFamily}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${item.lineTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),

            const Divider(height: 32),

            // Shipping address
            if (order.shippingAddress != null) ...[
              const Text('Delivery Address',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.shippingAddress!.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(order.shippingAddress!.fullAddress,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    if (order.shippingAddress!.phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Phone: ${order.shippingAddress!.phone}',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const Divider(height: 32),
            ],

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '₹${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}, '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
