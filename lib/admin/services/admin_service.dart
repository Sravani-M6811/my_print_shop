import 'package:cloud_firestore/cloud_firestore.dart';
import '../../frontend/models/order_item.dart';
import '../../frontend/services/cart_service.dart';

/// Service for admin-only operations: role checks, cross-user order queries,
/// and order-status management.
///
/// Admin access is determined by the existence of a document at
/// `admins/{uid}` in Firestore. No passwords or secrets live in client code.
class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns `true` when [uid] has an `admins/{uid}` document.
  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _db.collection('admins').doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Stream that emits `true`/`false` whenever the admin doc is created or
  /// deleted — useful for live checks without polling.
  Stream<bool> isAdminStream(String uid) {
    return _db.collection('admins').doc(uid).snapshots().map(
          (doc) => doc.exists,
        );
  }

  // ── All Orders ────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _allOrders =>
      _db.collection('allOrders');

  /// Fetch every order across all customers, newest first.
  Future<List<OrderItem>> fetchAllOrders() async {
    try {
      final snapshot =
          await _allOrders.orderBy('orderDate', descending: true).get();
      return snapshot.docs
          .map((doc) => CartService.orderFromMap(doc.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Real-time stream of all orders (newest first).
  Stream<List<OrderItem>> allOrdersStream() {
    return _allOrders.orderBy('orderDate', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((doc) => CartService.orderFromMap(doc.data()))
              .toList(),
        );
  }

  /// Update the fulfilment status of an order. Writes to both the `allOrders`
  /// mirror and the customer's own `users/{uid}/orders/{orderId}` document so
  /// the customer app sees the same status through the existing order system.
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final doc = await _allOrders.doc(orderId).get();
      if (!doc.exists) return false;

      final data = doc.data() ?? const {};
      final userId = data['userId'] as String?;

      final batch = _db.batch();
      batch.update(_allOrders.doc(orderId), {'status': status});
      if (userId != null && userId.isNotEmpty) {
        batch.update(
          _db.collection('users').doc(userId).collection('orders').doc(orderId),
          {'status': status},
        );
      }
      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Compute dashboard statistics from a list of orders.
  AdminStats computeStats(List<OrderItem> orders) {
    int pending = 0;
    int confirmed = 0;
    int printing = 0;
    int shipped = 0;
    int delivered = 0;
    int cancelled = 0;
    double totalRevenue = 0;

    for (final o in orders) {
      switch (o.status) {
        case 'Pending':
          pending++;
          break;
        case 'Confirmed':
          confirmed++;
          break;
        case 'Printing':
          printing++;
          break;
        case 'Shipped':
          shipped++;
          break;
        case 'Delivered':
          delivered++;
          break;
        case 'Cancelled':
          cancelled++;
          break;
      }
      if (o.paymentStatus == PaymentStatus.paid) {
        totalRevenue += o.totalAmount;
      }
    }

    return AdminStats(
      totalOrders: orders.length,
      pending: pending,
      confirmed: confirmed,
      printing: printing,
      shipped: shipped,
      delivered: delivered,
      cancelled: cancelled,
      totalRevenue: totalRevenue,
    );
  }
}

/// Aggregated dashboard statistics derived from all orders.
class AdminStats {
  final int totalOrders;
  final int pending;
  final int confirmed;
  final int printing;
  final int shipped;
  final int delivered;
  final int cancelled;
  final double totalRevenue;

  const AdminStats({
    required this.totalOrders,
    required this.pending,
    required this.confirmed,
    required this.printing,
    required this.shipped,
    required this.delivered,
    required this.cancelled,
    required this.totalRevenue,
  });
}
