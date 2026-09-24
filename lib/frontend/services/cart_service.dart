import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, Colors;
import '../models/address.dart';
import '../models/cart_item.dart';
import '../models/order_item.dart';

/// Firestore persistence for the live cart/order system.
class CartService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ---------- Serialization ----------

  static Map<String, dynamic> itemToMap(CartItem item) => {
        'id': item.id,
        'title': item.title,
        'price': item.price,
        'category': item.category,
        'customText': item.customText,
        'selectedSide': item.selectedSide,
        'fontFamily': item.fontFamily,
        'color': item.color.toARGB32(),
        'imagePath': item.imagePath,
        'quantity': item.quantity,
        'baseProductTitle': item.baseProductTitle,
        'selectedVariant': item.selectedVariant,
        'designName': item.designName,
        'designId': item.designId,
        'baseProductId': item.baseProductId,
        'printPosition': item.printPosition,
        'uploadedDesignPath': item.uploadedDesignPath,
        'size': item.size,
        'material': item.material,
        'measurements': (item.measurements)
            .map((m) => {'label': m.key, 'value': m.value})
            .toList(),
        'stitching': item.stitching,
      };

  static CartItem itemFromMap(Map<String, dynamic> map) => CartItem(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        category: map['category'] ?? '',
        customText: map['customText'] ?? '',
        selectedSide: map['selectedSide'] ?? 'Front',
        fontFamily: map['fontFamily'] ?? 'Sans-Serif',
        color: Color(map['color'] ?? Colors.black.toARGB32()),
        imagePath: map['imagePath'],
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        baseProductTitle: map['baseProductTitle'] as String?,
        selectedVariant: map['selectedVariant'] as String?,
        designName: map['designName'] as String?,
        designId: map['designId'] as String?,
        baseProductId: map['baseProductId'] as String?,
        printPosition: map['printPosition'] as String?,
        uploadedDesignPath: map['uploadedDesignPath'] as String?,
        size: map['size'] as String?,
        material: map['material'] as String?,
        measurements: ((map['measurements'] as List<dynamic>?) ?? [])
            .map<MapEntry<String, String>>((m) {
          final entry = Map<String, dynamic>.from(m as Map);
          return MapEntry('${entry['label']}', '${entry['value']}');
        }).toList(),
        stitching: map['stitching'] as String?,
      );

  static Map<String, dynamic> orderToMap(OrderItem order) => {
        'orderId': order.orderId,
        'totalAmount': order.totalAmount,
        'orderDate': order.orderDate.toIso8601String(),
        'status': order.status,
        'paymentStatus': order.paymentStatus,
        'items': order.items.map(itemToMap).toList(),
        'shippingAddress': order.shippingAddress?.toMap(),
        'paymentMethod': order.paymentMethod,
        'paymentId': order.paymentId,
      };

  static OrderItem orderFromMap(Map<String, dynamic> map) => OrderItem(
        orderId: map['orderId'] ?? '',
        totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
        orderDate: DateTime.parse(map['orderDate'] ??
            DateTime.fromMillisecondsSinceEpoch(0).toIso8601String()),
        status: map['status'] ?? 'Processing',
        // Older records predate paymentStatus. Infer: an online method with a
        // captured payment id is treated as paid; everything else as unpaid
        // (COD). Keeps legacy orders readable without guessing a false state.
        paymentStatus: map['paymentStatus'] ??
            ('${map['paymentMethod']}' != 'Cash on Delivery' &&
                    (map['paymentId'] as String?)?.isNotEmpty == true
                ? PaymentStatus.paid
                : PaymentStatus.unpaid),
        items: ((map['items'] as List<dynamic>?) ?? [])
            .map<CartItem>((item) =>
                itemFromMap(Map<String, dynamic>.from(item as Map)))
            .toList(),
        shippingAddress: map['shippingAddress'] is Map<String, dynamic>
            ? Address.fromMap(
                Map<String, dynamic>.from(map['shippingAddress'] as Map))
            : null,
        paymentMethod: map['paymentMethod'] ?? 'Cash on Delivery',
        paymentId: map['paymentId'] as String?,
      );

  // ---------- Paths ----------

  CollectionReference<Map<String, dynamic>> _cartRef(String uid) =>
      _db.collection('users').doc(uid).collection('cart');

  CollectionReference<Map<String, dynamic>> _ordersRef(String uid) =>
      _db.collection('users').doc(uid).collection('orders');

  // ---------- Cart ops ----------

  Future<void> saveCartItem(String uid, CartItem item) =>
      _cartRef(uid).doc(item.id).set(itemToMap(item));

  Future<void> deleteCartItem(String uid, String itemId) =>
      _cartRef(uid).doc(itemId).delete();

  Future<List<CartItem>> fetchCart(String uid) async {
    final snapshot = await _cartRef(uid).get();
    return snapshot.docs.map((doc) => itemFromMap(doc.data())).toList();
  }

  // ---------- Order ops ----------

  Future<List<OrderItem>> fetchOrders(String uid) async {
    final snapshot = await _ordersRef(uid).get();
    return snapshot.docs.map((doc) => orderFromMap(doc.data())).toList();
  }

  /// Full serialized document for the top-level `allOrders/{orderId}` mirror:
  /// the complete order snapshot plus the owning user's id so the admin panel
  /// can aggregate across customers.
  static Map<String, dynamic> orderToMirrorMap(OrderItem order, String uid) => {
        ...orderToMap(order),
        'userId': uid,
      };

  /// Describes every write issued when placing [order] for [uid], in the order
  /// they are applied to a single atomic batch:
  ///   1. the customer's own `users/{uid}/orders/{orderId}` document,
  ///   2. the admin `allOrders/{orderId}` mirror (with `userId` embedded),
  ///   3. one delete per cart item.
  ///
  /// Kept separate from the Firestore calls so tests can assert the exact
  /// customer+admin consistency contract without a live database.
  @visibleForTesting
  static List<Map<String, dynamic>> buildOrderCommitPlan(
      String uid, OrderItem order) {
    return [
      {
        'op': 'set_order',
        'doc': 'users/$uid/orders/${order.orderId}',
        'data': orderToMap(order),
      },
      {
        'op': 'set_admin_mirror',
        'doc': 'allOrders/${order.orderId}',
        'data': orderToMirrorMap(order, uid),
      },
      for (final item in order.items)
        {
          'op': 'delete_cart_item',
          'doc': 'users/$uid/cart/${item.id}',
        },
    ];
  }

  /// Persists [order] for [uid] and clears the purchased cart items in ONE
  /// atomic batch that also writes the admin `allOrders` mirror. Customer
  /// order + cart deletion + admin visibility either all succeed or none do,
  /// so an order can never be shown to the customer without also reaching the
  /// admin panel.
  Future<void> commitOrder(String uid, OrderItem order) async {
    final batch = _db.batch();
    for (final op in buildOrderCommitPlan(uid, order)) {
      final data = op['data'] as Map<String, dynamic>?;
      switch (op['op']) {
        case 'set_order':
          batch.set(_ordersRef(uid).doc(order.orderId), data!);
          break;
        case 'set_admin_mirror':
          batch.set(_db.collection('allOrders').doc(order.orderId), data!);
          break;
        case 'delete_cart_item':
          final docId = op['doc'].toString().split('/').last;
          batch.delete(_cartRef(uid).doc(docId));
          break;
        default:
          throw ArgumentError('Unknown commit plan op: ${op['op']}');
      }
    }
    await batch.commit();
  }

  Future<void> clearCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await _cartRef(user.uid).get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Pushes the local-only portions of [localCart]/[localOrders] into the
  /// user's cloud collections without disturbing anything the cloud already
  /// holds (deduplicated by item id and order id). Used on sign-in when the
  /// account already has cloud data, so device-held guest items are never
  /// discarded.
  Future<void> mergeLocalIntoCloud(
    String uid,
    List<CartItem> localCart,
    List<OrderItem> localOrders,
    List<CartItem> cloudCart,
    List<OrderItem> cloudOrders,
  ) async {
    final batch = _db.batch();
    for (final item in localCart) {
      if (!cloudCart.any((c) => c.id == item.id)) {
        batch.set(_cartRef(uid).doc(item.id), itemToMap(item));
      }
    }
    for (final order in localOrders) {
      if (!cloudOrders.any((o) => o.orderId == order.orderId)) {
        batch.set(_ordersRef(uid).doc(order.orderId), orderToMap(order));
        batch.set(_db.collection('allOrders').doc(order.orderId),
            orderToMirrorMap(order, uid));
      }
    }
    await batch.commit();
  }

  Future<void> migrateAll(
      String uid, List<CartItem> cart, List<OrderItem> orders) async {
    final batch = _db.batch();
    for (final item in cart) {
      batch.set(_cartRef(uid).doc(item.id), itemToMap(item));
    }
    for (final order in orders) {
      batch.set(_ordersRef(uid).doc(order.orderId), orderToMap(order));
      // Mirror legacy locally-held orders to the admin collection too, so the
      // admin panel sees them exactly like newly-placed orders.
      batch.set(_db.collection('allOrders').doc(order.orderId),
          orderToMirrorMap(order, uid));
    }
    await batch.commit();
  }
}
