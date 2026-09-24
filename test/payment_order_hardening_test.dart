import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/models/cart_item.dart';
import 'package:my_print_shop/frontend/models/order_item.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/services/cart_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CartItem makeItem({String id = 'i1', double price = 499, int quantity = 1}) =>
      CartItem(
        id: id,
        title: 'Plain Saree · Floral Design',
        category: 'Sarees',
        customText: 'Hello',
        selectedSide: 'Front',
        fontFamily: 'Sans-Serif',
        price: price,
        color: const Color(0xFFFFFFFF),
        quantity: quantity,
        baseProductTitle: 'Plain Saree',
        baseProductId: 'saree-1',
        selectedVariant: 'Black',
        printPosition: 'Back',
        uploadedDesignPath: 'uploads/me.png',
        size: 'L',
        material: '100% Cotton',
      );

  OrderItem makeOrder({
    String orderId = 'ORD1',
    double total = 998,
    String paymentStatus = PaymentStatus.unpaid,
    String paymentMethod = 'Cash on Delivery',
    String? paymentId,
  }) =>
      OrderItem(
        orderId: orderId,
        totalAmount: total,
        orderDate: DateTime(2026, 1, 1),
        status: 'Pending',
        paymentStatus: paymentStatus,
        items: [makeItem(), makeItem(id: 'i2', price: 499)],
        paymentMethod: paymentMethod,
        paymentId: paymentId,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CartService.commitOrder write plan (single atomic batch)', () {
    test('writes the customer order doc, the admin mirror, and cart deletes '
        'in one plan', () {
      final order = makeOrder(orderId: 'ORD9', total: 998, paymentStatus: 'unpaid');
      final plan = CartService.buildOrderCommitPlan('u_1', order);

      expect(plan.map((op) => op['op']).toList(),
          ['set_order', 'set_admin_mirror', 'delete_cart_item', 'delete_cart_item']);

      // op 0: the customer's own order document.
      expect(plan[0]['doc'], 'users/u_1/orders/ORD9');
      expect(plan[0]['data'], CartService.orderToMap(order));

      // op 1: the admin mirror carries the full snapshot plus the userId so
      // the admin panel knows which customer ordered.
      expect(plan[1]['doc'], 'allOrders/ORD9');
      final mirror = plan[1]['data'] as Map<String, dynamic>;
      expect(mirror['userId'], 'u_1');
      expect(mirror['orderId'], 'ORD9');
      expect(mirror['totalAmount'], 998);
      expect(mirror['paymentStatus'], PaymentStatus.unpaid);
      expect(mirror['paymentMethod'], 'Cash on Delivery');
      expect(mirror['items'], hasLength(2));
      expect((mirror['items'] as List).first['baseProductId'], 'saree-1');

      // ops 2..N: every purchased cart item is deleted after ordering.
      expect(plan[2]['doc'], 'users/u_1/cart/i1');
      expect(plan[3]['doc'], 'users/u_1/cart/i2');
    });

    test('admin mirror reflects a paid online order with its payment id', () {
      final order = makeOrder(
        orderId: 'ORD_PAID',
        total: 1997,
        paymentStatus: PaymentStatus.paid,
        paymentMethod: 'UPI / Online',
        paymentId: 'pay_abc123',
      );
      final plan = CartService.buildOrderCommitPlan('u_2', order);
      final mirror = plan[1]['data'] as Map<String, dynamic>;

      expect(mirror['paymentStatus'], PaymentStatus.paid);
      expect(mirror['paymentId'], 'pay_abc123');
      expect(mirror['paymentMethod'], 'UPI / Online');
      expect(mirror['userId'], 'u_2');
    });

    test('one order with many items deletes each cart line exactly once', () {
      final order = OrderItem(
        orderId: 'ORD_MANY',
        totalAmount: 300,
        orderDate: DateTime(2026, 1, 1),
        status: 'Pending',
        paymentStatus: PaymentStatus.unpaid,
        items: [
          makeItem(id: 'a'),
          makeItem(id: 'b'),
          makeItem(id: 'c'),
          makeItem(id: 'd'),
        ],
        paymentMethod: 'Cash on Delivery',
      );
      final plan = CartService.buildOrderCommitPlan('u_3', order);
      final deletes = plan
          .where((op) => op['op'] == 'delete_cart_item')
          .map((op) => op['doc'])
          .toList();
      expect(deletes, ['users/u_3/cart/a', 'users/u_3/cart/b', 'users/u_3/cart/c', 'users/u_3/cart/d']);
    });
  });

  group('AppState COD + verified-payment order creation', () {
    test('COD order is created Pending and never marked paid', () async {
      final state = AppState();
      await state.initialized;
      state.addToCart(makeItem(price: 499, quantity: 2));

      final ok = await state.placeOrder(
        orderId: 'ORD_COD',
        paymentMethod: 'Cash on Delivery',
        paymentStatus: PaymentStatus.unpaid,
      );

      expect(ok, isTrue);
      final order = state.orders.single;
      expect(order.orderId, 'ORD_COD');
      expect(order.status, 'Pending');
      expect(order.paymentStatus, PaymentStatus.unpaid); // COD is never 'paid'
      expect(order.paymentId, isNull);
      expect(order.paymentMethod, 'Cash on Delivery');
      expect(order.totalAmount, 998);
      expect(state.cartItems, isEmpty);
    });

    test('verified online payment is recorded as paid with its payment id',
        () async {
      final state = AppState();
      await state.initialized;
      state.addToCart(makeItem(id: 'x', price: 1997));

      final ok = await state.placeOrder(
        orderId: 'ORD_ONLINE',
        paymentMethod: 'UPI / Online',
        paymentStatus: PaymentStatus.paid,
        paymentId: 'pay_xyz',
      );

      expect(ok, isTrue);
      final order = state.orders.single;
      expect(order.paymentStatus, PaymentStatus.paid);
      expect(order.paymentId, 'pay_xyz');
      expect(order.paymentMethod, 'UPI / Online');
      expect(order.status, 'Pending');
    });

    test('payment recorded as pending when verification is unavailable',
        () async {
      final state = AppState();
      await state.initialized;
      state.addToCart(makeItem(price: 100));

      await state.placeOrder(
        orderId: 'ORD_PENDING',
        paymentMethod: 'UPI / Online',
        paymentStatus: PaymentStatus.pending,
      );

      final order = state.orders.single;
      // A pending (unverified) payment is never claimed as paid.
      expect(order.paymentStatus, PaymentStatus.pending);
      expect(order.paymentStatus, isNot(PaymentStatus.paid));
    });
  });

  group('duplicate-order protection', () {
    test('reusing the same orderId cannot create a second order', () async {
      final state = AppState();
      await state.initialized;
      state.addToCart(makeItem(price: 100));
      final firstOk = await state.placeOrder(orderId: 'ORD_DUP');
      expect(firstOk, isTrue);
      expect(state.orders, hasLength(1));

      // A duplicate callback/retry with the SAME orderId must be a no-op.
      state.addToCart(makeItem(id: 'zz', price: 100));
      final secondOk = await state.placeOrder(orderId: 'ORD_DUP');

      expect(secondOk, isTrue);
      expect(state.orders, hasLength(1));
      expect(state.orders.single.orderId, 'ORD_DUP');
    });

    test('cart snapshot (qty, price, variants, artwork) survives into the '
        'order', () async {
      final state = AppState();
      await state.initialized;
      state.addToCart(makeItem().copyWith(
        quantity: 3,
        baseProductTitle: 'Plain T-Shirt',
        printPosition: 'Back',
        uploadedDesignPath: 'uploads/me.png',
      ));

      await state.placeOrder(orderId: 'ORD_SNAP');

      final orderItem = state.orders.single.items.first;
      expect(orderItem.quantity, 3);
      expect(orderItem.lineTotal, 1497);
      expect(orderItem.baseProductTitle, 'Plain T-Shirt');
      expect(orderItem.baseProductId, 'saree-1');
      expect(orderItem.printPosition, 'Back');
      expect(orderItem.uploadedDesignPath, 'uploads/me.png');
    });
  });

  group('order persistence failure never clears the cart', () {
    test('commit returning false rolls the order back and keeps the cart',
        () async {
      final state = _RejectingPersistence();
      await state.initialized;
      state.addToCart(makeItem(id: 'k1', price: 499, quantity: 2));

      final ok = await state.placeOrder(orderId: 'ORD_FAIL');
      expect(ok, isFalse);
      expect(state.orders, isEmpty);
      expect(state.cartItems, hasLength(1));
      expect(state.cartItems.single.id, 'k1');
      expect(state.totalPrice, 998);
    });

    test('commit throwing rolls the order back and keeps the cart', () async {
      final state = _ThrowingPersistence();
      await state.initialized;
      state.addToCart(makeItem(id: 'k2', price: 250));

      final ok = await state.placeOrder(orderId: 'ORD_THROW');
      expect(ok, isFalse);
      expect(state.orders, isEmpty);
      expect(state.cartItems, hasLength(1));
      expect(state.cartItems.single.id, 'k2');
    });
  });

  group('Firestore security rules stay strict (regression guard)', () {
    test('rules still exist and allow only safe allOrders writes', () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, isNotEmpty);
      // No bare authenticated write to the admin mirror collection.
      expect(rules, isNot(contains('allow write: if request.auth != null)')));
      // Customers may only create mirrors carrying their OWN uid…
      expect(rules, contains('request.resource.data.userId == request.auth.uid'));
      // …and a 'paid' mirror must reference an actual payment id…
      expect(rules, contains('request.resource.data.paymentId'));
      // …while updates/deletes belong to admins only.
      expect(rules, contains('allow update, delete: if isAdmin()'));
      // The admin panel can read the mirror and admins manage catalogue.
      expect(rules, contains('allow read: if isAdmin()'));
      expect(rules, contains('allow write: if isAdmin()'));
    });
  });
}

/// Simulates a cloud write that reports failure without throwing.
class _RejectingPersistence extends AppState {
  @override
  Future<bool> persistOrderToFirestore(OrderItem order) async => false;
}

/// Simulates a cloud write that throws.
class _ThrowingPersistence extends AppState {
  @override
  Future<bool> persistOrderToFirestore(OrderItem order) async {
    throw Exception('simulated Firestore write failure');
  }
}
