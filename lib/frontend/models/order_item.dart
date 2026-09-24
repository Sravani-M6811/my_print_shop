import 'address.dart';
import 'cart_item.dart';

/// Payment lifecycle for an order:
///   * [PaymentStatus.paid]    - online payment successfully verified (server-side).
///   * [PaymentStatus.pending] - online payment received but awaiting server
///                               verification (backend unreachable/not verified yet).
///   * [PaymentStatus.unpaid]  - Cash on Delivery (to be paid on delivery).
class PaymentStatus {
  static const String paid = 'paid';
  static const String pending = 'pending';
  static const String unpaid = 'unpaid';

  const PaymentStatus._();
}

class OrderItem {
  final String orderId;
  final double totalAmount;
  final DateTime orderDate;

  /// Order lifecycle status (e.g. 'Print Processing'). This is the fulfilment
  /// status, distinct from [paymentStatus].
  final String status;

  /// Payment state: one of [PaymentStatus].
  final String paymentStatus;
  final List<CartItem> items;
  final Address? shippingAddress;
  final String paymentMethod;
  final String? paymentId;

  const OrderItem({
    required this.orderId,
    required this.totalAmount,
    required this.orderDate,
    required this.status,
    required this.items,
    this.paymentStatus = PaymentStatus.unpaid,
    this.shippingAddress,
    this.paymentMethod = 'Cash on Delivery',
    this.paymentId,
  });
}

