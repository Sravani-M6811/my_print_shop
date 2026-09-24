import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/models/address.dart';
import 'package:my_print_shop/frontend/models/cart_item.dart';
import 'package:my_print_shop/frontend/models/order_item.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/services/backend_service.dart';
import 'package:my_print_shop/frontend/services/cart_service.dart';

// ---------------------------------------------------------------------------
// Phase 2D contract: Cart -> Checkout -> Payment verification.
// Locks the exact behaviour the checkout sheet relies on so a regression in
// retention, idempotency or payment status is caught without a live gateway.
// ---------------------------------------------------------------------------

CartItem _fullItem({String id = 'i1', int quantity = 2}) => CartItem(
      id: id,
      title: 'Plain Saree · Golden Floral Motif',
      category: 'Sarees',
      customText: 'Hello',
      selectedSide: 'Back',
      fontFamily: 'Cursive',
      price: 499,
      color: const Color(0xFF000000),
      imagePath: 'asset:images/designs/sarees/floral.png',
      quantity: quantity,
      baseProductTitle: 'Plain Saree',
      baseProductId: 'saree-1',
      selectedVariant: 'Black',
      designName: 'Golden Floral Motif',
      designId: 'design-42',
      printPosition: 'Back',
      uploadedDesignPath: 'uploads/art.png',
      size: 'L',
      material: '100% Cotton',
      measurements: const [
        MapEntry('Length', '6m'),
        MapEntry('Width', '1.2m'),
      ],
      stitching: 'Without Stitching',
    );

Address _fullAddress() => const Address(
      fullName: 'Ada Lovelace',
      phone: '9876543210',
      houseFlat: '12, Lake View',
      streetArea: 'MG Road',
      city: 'Bangalore',
      state: 'Karnataka',
      pinCode: '560001',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Cart -> Order retention', () {
    test('every configured field survives placeOrder into the order line',
        () async {
      final state = AppState();
      await state.initialized;
      state.addToCart(_fullItem());

      final ok =
          await state.placeOrder(orderId: 'ORD_RETAIN', paymentMethod: 'UPI / Online');
      expect(ok, isTrue);

      final item = state.orders.single.items.single;
      // Base product
      expect(item.baseProductTitle, 'Plain Saree');
      expect(item.baseProductId, 'saree-1');
      // Selected design
      expect(item.designName, 'Golden Floral Motif');
      expect(item.designId, 'design-42');
      // Customization
      expect(item.selectedVariant, 'Black');
      expect(item.size, 'L');
      expect(item.material, '100% Cotton');
      expect(item.printPosition, 'Back');
      expect(item.customText, 'Hello');
      expect(item.fontFamily, 'Cursive');
      expect(item.stitching, 'Without Stitching');
      expect(item.measurements, hasLength(2));
      expect(item.measurements.first.key, 'Length');
      expect(item.measurements.first.value, '6m');
      // Image
      expect(item.imagePath, 'asset:images/designs/sarees/floral.png');
      expect(item.uploadedDesignPath, 'uploads/art.png');
      // Quantity + price
      expect(item.quantity, 2);
      expect(item.price, 499);
      expect(item.lineTotal, 998);
    });

    test('quantity and price round-trip through local serialization',
        () async {
      final restored = CartService.itemFromMap(
          CartService.itemToMap(_fullItem()));
      expect(restored.quantity, 2);
      expect(restored.lineTotal, 998);
      expect(restored.designId, 'design-42');
      expect(restored.imagePath, 'asset:images/designs/sarees/floral.png');
      expect(restored.stitching, 'Without Stitching');
    });
  });

  group('Checkout details + total', () {
    test('customer + shipping address and total are retained on the order',
        () async {
      final state = AppState();
      await state.initialized;
      state.addToCart(_fullItem(id: 'a', quantity: 1));
      state.addToCart(_fullItem(id: 'b', quantity: 3));

      final ok = await state.placeOrder(
        orderId: 'ORD_CHECKOUT',
        shippingAddress: _fullAddress(),
        paymentMethod: 'Cash on Delivery',
      );
      expect(ok, isTrue);

      final order = state.orders.single;
      expect(order.totalAmount, 499 + 499 * 3);
      final addr = order.shippingAddress;
      expect(addr, isNotNull);
      expect(addr!.fullName, 'Ada Lovelace');
      expect(addr.phone, '9876543210');
      expect(addr.houseFlat, '12, Lake View');
      expect(addr.streetArea, 'MG Road');
      expect(addr.city, 'Bangalore');
      expect(addr.state, 'Karnataka');
      expect(addr.pinCode, '560001');
      expect(addr.fullAddress,
          '12, Lake View, MG Road, Bangalore, Karnataka - 560001');
    });

    test('shipping address round-trips through order serialization', () {
      final order = OrderItem(
        orderId: 'ORD_ADDR',
        totalAmount: 998,
        orderDate: DateTime(2026, 1, 1),
        status: 'Pending',
        paymentStatus: PaymentStatus.unpaid,
        items: [_fullItem()],
        shippingAddress: _fullAddress(),
        paymentMethod: 'Cash on Delivery',
      );
      final restored =
          CartService.orderFromMap(CartService.orderToMap(order));
      expect(restored.shippingAddress?.fullAddress,
          '12, Lake View, MG Road, Bangalore, Karnataka - 560001');
      expect(restored.shippingAddress?.pinCode, '560001');
    });
  });

  group('Payment status correctness', () {
    test('verified online payment is paid with the payment id', () async {
      final state = AppState();
      await state.initialized;
      state.addToCart(_fullItem());
      await state.placeOrder(
        orderId: 'ORD_PAID2',
        paymentMethod: 'UPI / Online',
        paymentStatus: PaymentStatus.paid,
        paymentId: 'pay_ok',
      );
      final order = state.orders.single;
      expect(order.paymentStatus, PaymentStatus.paid);
      expect(order.paymentId, 'pay_ok');
    });

    test('unverified payment is pending and never claimed as paid', () async {
      final state = AppState();
      await state.initialized;
      state.addToCart(_fullItem());
      await state.placeOrder(
        orderId: 'ORD_PEND2',
        paymentMethod: 'UPI / Online',
        paymentStatus: PaymentStatus.pending,
        paymentId: 'pay_captured_not_verified',
      );
      final order = state.orders.single;
      expect(order.paymentStatus, PaymentStatus.pending);
      expect(order.paymentStatus, isNot(PaymentStatus.paid));
    });

    test('COD is unpaid with no payment id', () async {
      final state = AppState();
      await state.initialized;
      state.addToCart(_fullItem());
      await state.placeOrder(
        orderId: 'ORD_COD2',
        paymentMethod: 'Cash on Delivery',
        paymentStatus: PaymentStatus.unpaid,
      );
      final order = state.orders.single;
      expect(order.paymentStatus, PaymentStatus.unpaid);
      expect(order.paymentId, isNull);
      expect(order.paymentMethod, 'Cash on Delivery');
    });
  });

  group('Retry + idempotency', () {
    test('saving a captured payment can never create a duplicate order',
        () async {
      final state = AppState();
      await state.initialized;
      state.addToCart(_fullItem(quantity: 1));

      // First (successful) save.
      expect(await state.placeOrder(orderId: 'ORD_IDEM'), isTrue);
      expect(state.orders, hasLength(1));

      // Duplicate callback with the SAME orderId (payment sheet retry) is a
      // no-op — the already-saved order must not be duplicated.
      state.addToCart(_fullItem(id: 'new', quantity: 1));
      expect(await state.placeOrder(orderId: 'ORD_IDEM'), isTrue);
      expect(state.orders, hasLength(1));
      expect(state.orders.single.orderId, 'ORD_IDEM');
    });

    test('a failed save rolls back and a retry with the same orderId succeeds '
        'once', () async {
      final state = _FlakyPersistence(failures: 1);
      await state.initialized;
      state.addToCart(_fullItem());

      // First attempt fails: order rolled back, cart intact.
      final first = await state.placeOrder(
        orderId: 'ORD_RETRY',
        paymentMethod: 'UPI / Online',
        paymentStatus: PaymentStatus.paid,
        paymentId: 'pay_r1',
      );
      expect(first, isFalse);
      expect(state.orders, isEmpty);
      expect(state.cartItems, hasLength(1));

      // Retry re-persists the SAME orderId — one order, not two.
      final second = await state.placeOrder(
        orderId: 'ORD_RETRY',
        paymentMethod: 'UPI / Online',
        paymentStatus: PaymentStatus.paid,
        paymentId: 'pay_r1',
      );
      expect(second, isTrue);
      expect(state.orders, hasLength(1));
      expect(state.orders.single.orderId, 'ORD_RETRY');
      expect(state.orders.single.paymentStatus, PaymentStatus.paid);
    });
  });

  group('Payment verification stays server-side', () {
    test('client forwards paymentId/orderId/signature/amount to the verify '
        'endpoint', () async {
      http.Request? captured;
      final service = BackendService(
        client: MockClient((req) async {
          captured = req;
          return http.Response(
            '{"success":true,"verificationAvailable":true,"verified":true}',
            200,
          );
        }),
      );
      final result = await service.verifyRazorpayPayment(
        paymentId: 'pay_sec',
        orderId: 'ord_sec',
        signature: 'sig_sec',
        amount: 998,
      );
      expect(result, PaymentVerification.verified);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/razorpay/verify');
      final body = captured!.body;
      expect(body, contains('pay_sec'));
      expect(body, contains('ord_sec'));
      expect(body, contains('sig_sec'));
      expect(body, contains('998'));
    });

    test('unverified signature maps to unverified, not paid', () async {
      final service = BackendService(
        client: MockClient((req) async => http.Response(
              '{"success":true,"verificationAvailable":true,"verified":false}',
              200,
            )),
      );
      final result = await service.verifyRazorpayPayment(
          paymentId: 'p', orderId: 'o', signature: 'bad');
      expect(result, PaymentVerification.unverified);
    });

    test('unavailable backend maps to unavailable (client never fabricates '
        'success)', () async {
      final offline = BackendService(
        client: MockClient((req) async => throw http.ClientException('offline')),
      );
      expect(
        await offline.verifyRazorpayPayment(
            paymentId: 'p', orderId: 'o', signature: 's'),
        PaymentVerification.unavailable,
      );
    });
  });
}

/// Persists the order a configured number of times as failed before succeeding,
/// so "retry after failure" can be exercised without a live database.
class _FlakyPersistence extends AppState {
  int failures;
  _FlakyPersistence({this.failures = 1});

  @override
  Future<bool> persistOrderToFirestore(OrderItem order) async {
    if (failures > 0) {
      failures--;
      return false;
    }
    return true;
  }
}
