import 'package:flutter/material.dart';
import '../../frontend/constants/asset_paths.dart';
import '../../frontend/models/cart_item.dart';
import '../../frontend/models/order_item.dart';
import '../services/admin_service.dart';

/// Admin Order Details — full order information plus fulfilment status
/// controls for the admin.
class AdminOrderDetailScreen extends StatefulWidget {
  final OrderItem order;
  final AdminService adminService;

  const AdminOrderDetailScreen({
    super.key,
    required this.order,
    required this.adminService,
  });

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  static const _statuses = [
    'Pending',
    'Confirmed',
    'Printing',
    'Shipped',
    'Delivered',
    'Cancelled',
  ];

  late String _status;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
  }

  Future<void> _updateStatus(String status) async {
    if (status == _status) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final ok = await widget.adminService.updateOrderStatus(
      widget.order.orderId,
      status,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _status = status;
      } else {
        _saveError = 'Could not update the status. Please try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final customer = _customerName;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          order.orderId,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status management card ──
              _StatusControlCard(
                current: _status,
                saving: _saving,
                error: _saveError,
                statuses: _statuses,
                onChanged: _updateStatus,
              ),
              const SizedBox(height: 16),

              // ── Order overview ──
              _SectionCard(
                title: 'Order Information',
                children: [
                  _InfoRow('Order ID', order.orderId),
                  _InfoRow('Placed on', _formatDateTime(order.orderDate)),
                  _InfoRow('Payment Method', order.paymentMethod),
                  _InfoRow('Payment Status', _paymentStatusLabel()),
                  if (order.paymentId != null && order.paymentId!.isNotEmpty)
                    _InfoRow('Payment ID', order.paymentId!),
                ],
              ),
              const SizedBox(height: 16),

              // ── Customer information ──
              if (order.shippingAddress != null) ...[
                _SectionCard(
                  title: 'Customer Information',
                  children: [
                    _InfoRow('Name', customer),
                    if (order.shippingAddress!.phone.isNotEmpty)
                      _InfoRow('Phone', order.shippingAddress!.phone),
                    _InfoRow(
                        'Address', order.shippingAddress!.fullAddress),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ── Ordered products ──
              _SectionCard(
                title: 'Ordered Products (${order.items.length})',
                children: [
                  for (final item in order.items) ...[
                    _ProductRow(item: item),
                    if (item != order.items.last) const Divider(height: 20),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ── Total ──
              _SectionCard(
                title: 'Total Amount',
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Grand Total',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '₹${order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _customerName {
    final a = widget.order.shippingAddress;
    if (a != null && a.fullName.isNotEmpty) return a.fullName;
    return 'Customer';
  }

  String _paymentStatusLabel() {
    final method = widget.order.paymentMethod.toLowerCase();
    if (method.contains('cash')) return 'Cash on Delivery';
    switch (widget.order.paymentStatus) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.pending:
        return 'Pending — awaiting verification';
      default:
        return 'Pending';
    }
  }
}

/// Reusable status + save control bar.
class _StatusControlCard extends StatelessWidget {
  final String current;
  final bool saving;
  final String? error;
  final List<String> statuses;
  final ValueChanged<String> onChanged;

  const _StatusControlCard({
    required this.current,
    required this.saving,
    required this.error,
    required this.statuses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Update Order Status',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in statuses)
                ChoiceChip(
                  label: Text(s),
                  selected: current == s,
                  selectedColor: const Color(0xFF6C5CE7),
                  labelStyle: TextStyle(
                    color: current == s ? Colors.white : Colors.grey.shade700,
                    fontWeight: current == s ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  showCheckmark: false,
                  onSelected: saving ? null : (_) => onChanged(s),
                ),
            ],
          ),
          if (saving) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Saving…', style: TextStyle(fontSize: 13)),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// A "label → value" row that wraps gracefully on narrow screens.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single ordered product line with its configuration details.
class _ProductRow extends StatelessWidget {
  final CartItem item;
  const _ProductRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final lineTotal = item.lineTotal;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            AssetPaths.productImageForCategory(item.category),
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 52,
              height: 52,
              color: Theme.of(context).colorScheme.outlineVariant,
              child: const Icon(Icons.image_not_supported, size: 24),
            ),
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
                item.category,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (item.baseProductTitle != null &&
                  item.baseProductTitle!.isNotEmpty)
                _detailLine('Base', item.baseProductTitle!),
              if (item.selectedVariant != null &&
                  item.selectedVariant!.isNotEmpty)
                _detailLine('Variant', item.selectedVariant!),
              if (item.size != null && item.size!.isNotEmpty)
                _detailLine('Size', item.size!),
              if (item.material != null && item.material!.isNotEmpty)
                _detailLine('Material', item.material!),
              if (item.designName != null && item.designName!.isNotEmpty)
                _detailLine('Design', item.designName!),
              if (item.printPosition != null && item.printPosition!.isNotEmpty)
                _detailLine('Position', item.printPosition!),
              if (item.stitching != null && item.stitching!.isNotEmpty)
                _detailLine('Stitching', item.stitching!),
              for (final m in item.measurements)
                if (m.value.isNotEmpty) _detailLine(m.key, m.value),
              if (item.customText.isNotEmpty)
                _detailLine('Text', '"${item.customText}"'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹$lineTotal',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            if (item.quantity > 1)
              Text(
                '${item.quantity} × ₹${item.price.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
          ],
        ),
      ],
    );
  }

  /// Small grey "Label: value" text.
  Widget _detailLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Text(
          '$label: $value',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      );
}

String _formatDateTime(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month
        .toString().padLeft(2, '0')}/${d.year} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
