import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../constants/asset_paths.dart';
import '../core/navigation_service.dart';
import '../data/product_catalog.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/app_state.dart';
import '../services/payment_service.dart';
import '../services/backend_service.dart';
import '../models/address.dart';
import '../../ui/widgets/catalogue_image.dart';
import 'address_screen.dart';
import 'order_confirmation_screen.dart';
import 'order_details_screen.dart';
import 'phone_login_screen.dart';
import 'product_detail_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Widget _buildMockupPreview(BuildContext context, CartItem item) {
    return Container(
      width: double.infinity,
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            AssetPaths.productImageForCategory(item.category),
            width: 90,
            height: 90,
            fit: BoxFit.contain,
            opacity: const AlwaysStoppedAnimation(0.3),
          ),
          if (item.imagePath != null && item.imagePath!.isNotEmpty)
            Positioned(
              top: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: item.imagePath!.startsWith('http')
                    ? Image.network(item.imagePath!, width: 40, height: 40, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink())
                    : kIsWeb
                        ? Image.network(item.imagePath!, width: 40, height: 40, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink())
                        : Image.file(File(item.imagePath!), width: 40, height: 40, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
          Positioned(
            bottom: 16,
            child: Text(
              item.customText.isEmpty ? 'Custom Design' : item.customText,
              style: TextStyle(color: item.color, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: item.fontFamily),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final cartItems = appState.cartItems;
    final orders = appState.orders;

    return Scaffold(
      appBar: AppBar(title: const Text('Cart & Orders'), centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Active Cart
            if (cartItems.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.shopping_bag_outlined, color: Color(0xFF6C5CE7)),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text('Items in your Cart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                AssetPaths.productImageForCategory(item.category),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.category}${item.quantity > 1 ? ' × ${item.quantity}' : ''}',
                                    style: const TextStyle(fontSize: 12)),
                                if (item.baseProductTitle != null && item.baseProductTitle!.isNotEmpty)
                                  Text('Print on: ${item.baseProductTitle}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (item.printPosition != null && item.printPosition!.isNotEmpty)
                                  Text('Position: ${item.printPosition}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (item.designName != null && item.designName!.isNotEmpty)
                                  Text('Design: ${item.designName}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (item.uploadedDesignPath != null && item.uploadedDesignPath!.isNotEmpty)
                                  Text('Artwork: Your uploaded design', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (item.selectedVariant != null && item.selectedVariant!.isNotEmpty)
                                  Text('Variant: ${item.selectedVariant}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (item.size != null && item.size!.isNotEmpty)
                                  Text('Size: ${item.size}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (item.material != null && item.material!.isNotEmpty)
                                  Text('Material: ${item.material}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (item.stitching != null && item.stitching!.isNotEmpty)
                                  Text('Stitching: ${item.stitching}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                for (final m in item.measurements)
                                  if (m.value.isNotEmpty)
                                    Text('${m.key}: ${m.value}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (item.customText.isNotEmpty)
                                  Text('Text: "${item.customText}" | Font: ${item.fontFamily}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${item.lineTotal.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    if (item.quantity > 1)
                                      Text(
                                        '${item.quantity} × ₹${item.price.toStringAsFixed(0)}',
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                      ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: item.quantity > 1
                                              ? () => appState.updateCartItemQuantity(item, item.quantity - 1)
                                              : null,
                                          child: const Icon(Icons.remove_circle_outline, size: 18),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        InkWell(
                                          onTap: () => appState.updateCartItemQuantity(item, item.quantity + 1),
                                          child: const Icon(Icons.add_circle_outline, size: 18),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => appState.removeFromCart(item),
                                ),
                              ],
                            ),
                          ),
                          _buildMockupPreview(context, item),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Total + Checkout
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('₹${appState.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final signedInOk = await _ensureSignedIn(context);
                          if (!signedInOk || !context.mounted) return;
                          final address = await Navigator.push<Address>(
                            context,
                            MaterialPageRoute(builder: (_) => const AddressScreen()),
                          );
                          if (address == null || !context.mounted) return;
                          _showPaymentSheet(context, appState, address);
                        },
                        child: const Text('Proceed to Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 2),
            ],

            // Orders
            if (orders.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.green.shade50,
                child: const Text('Placed Orders', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.green, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailsScreen(order: order),
                        ),
                      ),
                      child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(order.orderId,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(order.status, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                backgroundColor: const Color(0xFF6C5CE7),
                              ),
                            ],
                          ),
                          Text('₹${order.totalAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 50,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: order.items.length,
                              itemBuilder: (context, i) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.asset(
                                      AssetPaths.productImageForCategory(order.items[i].category),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ] else if (cartItems.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                child: Column(
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('Your cart is empty!', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Start shopping to add items', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 220,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => NavigationService.instance.switchTo(0),
                        icon: const Icon(Icons.storefront_rounded),
                        label: const Text('Start Shopping', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Trending Ready-Made rail ──
            // The cart's "main content" carousel: strictly ready-made/printed
            // products flagged as trending ([ProductCatalog.trendingReadyMade]
            // filters on productType == 'readyMade', so plain products and
            // designs can never leak in here).
            const SizedBox(height: 8),
            _TrendingReadyMadeSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Returns true if the user may proceed to checkout. Signed-in users pass
  /// immediately; guests are offered a choice to sign in or continue as guest
  /// (orders placed as guest are stored locally on the device).
  Future<bool> _ensureSignedIn(BuildContext context) async {
    if (FirebaseAuth.instance.currentUser != null) return true;

    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sign in to keep your orders synced across devices',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your cart is already safe locally. Signing in lets us back up your orders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue as Guest'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx, false);
                Navigator.push(
                  ctx,
                  MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                );
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );

    return result ?? true;
  }

  void _showPaymentSheet(BuildContext context, AppState appState, Address address) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Dismissing mid-payment would lose the sheet's idempotency state (the
      // captured-but-unsaved payment / the one orderId). A swipe or barrier
      // tap can no longer close it; the explicit Cancel button (disabled while
      // processing) is the only way out.
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PaymentSheet(
        appState: appState,
        address: address,
        onSuccess: () {
          final orders = appState.orders;
          if (orders.isNotEmpty && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: appState,
                  child: OrderConfirmationScreen(order: orders.first),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

/// The bottom-sheet payment confirmation flow.
///
/// Owns the real state (selected method, progress, and any error) so the
/// button is disabled while a payment/order request is in flight and the user
/// can always retry after a failure/cancellation. The order id is generated
/// once per sheet so retries write to the same Firestore doc (idempotent).
class _PaymentSheet extends StatefulWidget {
  final AppState appState;
  final Address address;
  final VoidCallback onSuccess;

  const _PaymentSheet({
    required this.appState,
    required this.address,
    required this.onSuccess,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  String selectedPayment = kIsWeb ? 'COD' : 'UPI';
  bool isProcessing = false;
  String? errorText;
  // High-entropy id generated once per sheet: the epoch-microseconds keep the
  // value unique across retries and devices, so concurrent/duplicate attempts
  // can never collide on (or silently overwrite) the same Firestore doc.
  final String orderId =
      'ORD${DateTime.now().microsecondsSinceEpoch.toString()}';

  /// True once a payment success callback has been received in THIS sheet.
  /// The bank charge is captured at that moment, so any later retry must ONLY
  /// re-persist the order (same orderId document) and never re-open the
  /// Razorpay checkout — a second checkout would bill the customer twice.
  bool _paymentReceived = false;
  String? _receivedPaymentId;
  String _receivedPaymentStatus = 'pending';

  AppState get appState => widget.appState;
  Address get address => widget.address;

  Future<void> _placeCodOrder() async {
    if (isProcessing) return;
    setState(() {
      isProcessing = true;
      errorText = null;
    });
    final ok = await appState.placeOrder(
      shippingAddress: address,
      paymentMethod: 'Cash on Delivery',
      paymentStatus: 'unpaid',
      orderId: orderId,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        isProcessing = false;
        errorText = 'Could not place your order. Your cart is safe — please try again.';
      });
      return;
    }
    _openConfirmation();
  }

  Future<void> _placeOnlineOrder() async {
    if (isProcessing) return;
    // A charge was already captured earlier in this sheet but the order never
    // got saved. Retry must re-persist the SAME order — never re-open the
    // gateway, which would create a brand-new charge.
    if (_paymentReceived) {
      await _retrySaveCapturedOrder();
      return;
    }
    setState(() {
      isProcessing = true;
      errorText = null;
    });

    final total = appState.totalPrice;
    final amountPaise = (total * 100).round();

    // 1. Create a server-authoritative Razorpay order. The amount is locked on
    // the server (and later cross-checked against the actual order fetched from
    // Razorpay), so the client can never tamper with the price. When the
    // backend or Razorpay credentials are unavailable we fail closed: the
    // customer is told to retry or use Cash on Delivery rather than being
    // offered an unverifiable online checkout.
    final serverOrder =
        await BackendService().createRazorpayOrder(
          amountPaise: amountPaise,
          receipt: orderId,
        );
    if (!mounted) return;

    final serverOrderId = serverOrder?['orderId'] as String?;
    if (serverOrder == null || serverOrderId == null || serverOrderId.isEmpty) {
      setState(() {
        isProcessing = false;
        errorText =
            'Online payment is temporarily unavailable. Please retry in a moment or choose Cash on Delivery.';
      });
      return;
    }

    final result = await PaymentService().startPayment(
      amountInRupees: total,
      description: '${appState.cartItems.length} item(s)',
      serverOrderId: serverOrderId,
    );

    if (!mounted) return;

    // Failure / cancellation: no order is created, the cart stays intact, and
    // the user can retry right away. A success callback alone is NEVER enough.
    if (result.status != PaymentResultStatus.paid) {
      setState(() {
        isProcessing = false;
        errorText = result.status == PaymentResultStatus.cancelled
            ? 'Payment cancelled. Your cart is safe — you can retry.'
            : 'Payment failed. Your cart is safe — please try again.';
      });
      return;
    }

    // Success callback received. Only after server-side signature AND amount
    // verification (against the server-created order) do we create a PAID order.
    final verification = await BackendService().verifyRazorpayPayment(
      paymentId: result.paymentId ?? '',
      orderId: serverOrderId,
      signature: result.signature ?? '',
      amount: total,
    );
    if (!mounted) return;

    if (verification == PaymentVerification.unverified) {
      // The payment was captured but the signature could NOT be confirmed.
      // Record it as a PENDING order instead of telling the user to retry —
      // a retry here would re-open the checkout and bill them a second time.
      // The order idempotency guard (same orderId) also prevents duplicates.
      _paymentReceived = true;
      _receivedPaymentId = result.paymentId;
      _receivedPaymentStatus = 'pending';
      final ok = await appState.placeOrder(
        shippingAddress: address,
        paymentMethod: 'UPI / Online',
        paymentId: result.paymentId,
        paymentStatus: 'pending',
        orderId: orderId,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          isProcessing = false;
          errorText =
              'Payment received, but the order could not be saved yet. Check your connection and tap Pay again — you will not be charged twice.';
        });
        return;
      }
      _openConfirmation();
      return;
    }

    // verified -> paid order
    // unavailable -> payment received but cannot be confirmed yet; record it
    // as PENDING (we never claim an unverified payment is paid).
    final paymentStatus = verification == PaymentVerification.verified
        ? 'paid'
        : 'pending';
    _paymentReceived = true;
    _receivedPaymentId = result.paymentId;
    _receivedPaymentStatus = paymentStatus;
    final ok = await appState.placeOrder(
      shippingAddress: address,
      paymentMethod: 'UPI / Online',
      paymentId: result.paymentId,
      paymentStatus: paymentStatus,
      orderId: orderId,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        isProcessing = false;
        errorText =
            'Payment received, but the order could not be saved yet. Check your connection and tap Pay again — you will not be charged twice.';
      });
      return;
    }
    _openConfirmation();
  }

  /// Re-saves a captured payment's order. Because the sheet keeps ONE [orderId]
  /// and passes it back to [AppState.placeOrder], this writes to the SAME
  /// Firestore doc that the previous attempt already wrote — it can never
  /// create a duplicate order and never opens the Razorpay checkout again.
  Future<void> _retrySaveCapturedOrder() async {
    setState(() {
      isProcessing = true;
      errorText = null;
    });
    final ok = await appState.placeOrder(
      shippingAddress: address,
      paymentMethod: 'UPI / Online',
      paymentId: _receivedPaymentId,
      paymentStatus: _receivedPaymentStatus,
      orderId: orderId,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        isProcessing = false;
        errorText =
            'Payment received, but the order could not be saved yet. Check your connection and tap Pay again — you will not be charged twice.';
      });
      return;
    }
    _openConfirmation();
  }

  void _openConfirmation() {
    // Close the payment sheet, then hand off to the CartScreen caller which
    // uses a longer-lived context to push the confirmation screen.
    Navigator.of(context).pop();
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Payment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                tooltip: 'Cancel',
                onPressed: isProcessing
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Order Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deliver to: ${address.fullName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(address.fullAddress, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const Divider(),
                Text('Total: ₹${appState.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                if (appState.cartItems.any((c) => c.quantity > 1))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Includes ${appState.cartItems.map((c) => c.quantity > 1 ? '${c.quantity}×${c.price.toInt()}' : null).whereType<String>().join(', ')}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Payment Options
          const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
          if (kIsWeb) ...[
            const SizedBox(height: 6),
            Text('Online payment (Razorpay) is not available on the web build yet. Please choose Cash on Delivery.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
          ],
          RadioGroup<String>(
            groupValue: selectedPayment,
            onChanged: (v) => setState(() => selectedPayment = v ?? 'COD'),
            child: Column(
              children: [
                if (!kIsWeb)
                  const RadioListTile<String>(
                    title: Text('UPI / GPay / PhonePe'),
                    value: 'UPI',
                  ),
                const RadioListTile<String>(
                  title: Text('Cash on Delivery'),
                  value: 'COD',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (errorText != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: isProcessing
                  ? null
                  : () {
                      if (selectedPayment == 'COD') {
                        _placeCodOrder();
                      } else {
                        _placeOnlineOrder();
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Pay ₹${appState.totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Trending Ready-Made rail ──────────────────────────────────────────────

/// The "Trending Ready-Made" carousel shown as part of the cart's main
/// content. Shows only trending ready-made products ([Product.isReadyMade]);
/// each card opens the real product detail flow where it can be bought.
class _TrendingReadyMadeSection extends StatelessWidget {
  const _TrendingReadyMadeSection();

  @override
  Widget build(BuildContext context) {
    final trending = ProductCatalog.trendingReadyMade;
    if (trending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: const Color(0xFFFFF3E0),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Color(0xFFF57C00), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Trending Ready-Made',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFFE65100)),
                ),
              ),
              Text(
                '${trending.length} picks',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: trending.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = trending[index];
              return _TrendingCard(
                product: product,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _TrendingCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: CatalogueImage(
                      imagePath: product.imagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Trending',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '₹${product.basePrice.toInt()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF6C5CE7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 26,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: onTap,
                        child: const Text('View'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
