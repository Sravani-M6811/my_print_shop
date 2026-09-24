import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/asset_paths.dart';
import '../models/cart_item.dart';
import '../models/order_item.dart';
import '../providers/app_state.dart';
import 'main_navigation_screen.dart';

/// Order confirmation screen.
///
/// Shows an HONEST payment/fulfilment state rather than always claiming the
/// order is "placed & paid":
///   * paid    - green check, "Payment Successful".
///   * pending - amber clock, "Order Received — payment pending verification".
///   * unpaid  - green check, "Order Placed — pay on delivery".
/// Item thumbnails prefer the real configured artwork/design image when
/// available and fall back to the category image.
class OrderConfirmationScreen extends StatelessWidget {
  final OrderItem order;

  const OrderConfirmationScreen({super.key, required this.order});

  bool get _paid => order.paymentStatus == PaymentStatus.paid;

  bool get _pending => order.paymentStatus == PaymentStatus.pending;

  String get _title => _paid
      ? 'Payment Successful'
      : _pending
          ? 'Order Received'
          : 'Order Placed';

  String get _subtitle => _paid
      ? 'Your payment is confirmed. We\'ll start printing your order soon.'
      : _pending
          ? 'Your payment is pending verification. We\'ll confirm once it is checked.'
          : 'Cash on Delivery — pay when your order arrives.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: _pending ? Colors.orange : Colors.green,
                  child: Icon(
                    _pending ? Icons.schedule_rounded : Icons.check_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _title,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order ID: ${order.orderId}',
                  style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6C5CE7),
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: ₹${order.totalAmount.toInt()}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Order Items Preview
                if (order.items.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: order.items.length,
                      itemBuilder: (context, index) {
                        final item = order.items[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _itemThumb(item, 80, 80),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${order.items.length} item(s) in this order',
                  style: TextStyle(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: Provider.of<AppState>(context, listen: false),
                            child: const MainNavigationScreen(),
                          ),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text('Continue Shopping',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Prefers the actual configured artwork/design image (uploaded file, URL or
  /// bundled asset) and falls back to the category image for the product.
  Widget _itemThumb(CartItem item, double w, double h) {
    final configured = item.imagePath;
    if (configured != null && configured.isNotEmpty) {
      final isHttp = configured.startsWith('http://') ||
          configured.startsWith('https://');
      if (isHttp) {
        return Image.network(
          configured,
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(item, w, h),
        );
      }
      if (configured.startsWith('asset')) {
        return Image.asset(
          configured.startsWith('asset:') ? configured.substring(6) : configured,
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(item, w, h),
        );
      }
      if (kIsWeb) {
        return Image.network(
          configured,
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(item, w, h),
        );
      }
      if (File(configured).existsSync()) {
        return Image.file(
          File(configured),
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(item, w, h),
        );
      }
    }
    return _fallback(item, w, h);
  }

  /// Fallback: the product category image (a bundled asset).
  Widget _fallback(CartItem item, double w, double h) {
    final category = item.category.isEmpty ? 'Custom' : item.category;
    return Image.asset(
      AssetPaths.productImageForCategory(category),
      width: w,
      height: h,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: w,
        height: h,
        color: Colors.grey.shade300,
        child: const Icon(Icons.shopping_bag, color: Colors.white54),
      ),
    );
  }
}
