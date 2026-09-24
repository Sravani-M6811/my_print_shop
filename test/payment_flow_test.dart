import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_print_shop/frontend/models/cart_item.dart';
import 'package:my_print_shop/frontend/models/order_item.dart';
import 'package:my_print_shop/frontend/services/backend_service.dart';
import 'package:my_print_shop/frontend/services/cart_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackendService.verifyRazorpayPayment', () {
    BackendService serviceReturning(Map<String, dynamic> body,
        {int statusCode = 200}) {
      final client = MockClient((request) async {
        // Assert the verification request carries paymentId/orderId/signature.
        final sent = jsonDecode(request.body) as Map<String, dynamic>;
        expect(sent['paymentId'], 'pay_1');
        expect(sent['orderId'], 'ord_1');
        expect(sent['signature'], 'sig_1');
        expect(sent['amount'], 1997);
        return http.Response(jsonEncode(body), statusCode);
      });
      return BackendService(client: client);
    }

    test('returns verified when the server confirms the signature', () async {
      final service = serviceReturning({
        'success': true,
        'verificationAvailable': true,
        'verified': true,
      });
      final result = await service.verifyRazorpayPayment(
        paymentId: 'pay_1',
        orderId: 'ord_1',
        signature: 'sig_1',
        amount: 1997,
      );
      expect(result, PaymentVerification.verified);
    });

    test('returns unverified when the signature does not match', () async {
      final service = serviceReturning({
        'success': true,
        'verificationAvailable': true,
        'verified': false,
      });
      final result = await service.verifyRazorpayPayment(
        paymentId: 'pay_1',
        orderId: 'ord_1',
        signature: 'sig_1',
        amount: 1997,
      );
      expect(result, PaymentVerification.unverified);
    });

    test('returns unavailable when the secret is not configured', () async {
      final service = serviceReturning({
        'success': false,
        'verificationAvailable': false,
        'message': 'secret not configured',
      });
      final result = await service.verifyRazorpayPayment(
        paymentId: 'pay_1',
        orderId: 'ord_1',
        signature: 'sig_1',
        amount: 1997,
      );
      expect(result, PaymentVerification.unavailable);
    });

    test('returns unavailable when the backend is unreachable (throws)',
        () async {
      final client = MockClient((request) async {
        throw Exception('connection refused');
      });
      final service = BackendService(client: client);
      final result = await service.verifyRazorpayPayment(
        paymentId: 'p',
        orderId: 'o',
        signature: 's',
      );
      expect(result, PaymentVerification.unavailable);
    });
  });

  group('OrderItem payment status serialization', () {
    CartItem makeItem() => CartItem(
          id: '1',
          title: 'Plain Saree · Floral Saree Design',
          category: 'Sarees',
          customText: 'Hello',
          selectedSide: 'Front',
          fontFamily: 'Sans-Serif',
          price: 499,
          color: const Color(0xFFFFFFFF),
          quantity: 2,
          baseProductTitle: 'Plain Saree',
        );

    OrderItem makeOrder({required String paymentStatus, String? paymentId}) =>
        OrderItem(
          orderId: 'ORD1',
          totalAmount: 998,
          orderDate: DateTime(2026, 1, 1),
          status: 'Print Processing',
          paymentStatus: paymentStatus,
          items: [makeItem()],
          paymentMethod: 'UPI / Online',
          paymentId: paymentId,
        );

    test('round-trips payment status and base product through maps', () {
      for (final status in ['paid', 'pending', 'unpaid']) {
        final order = makeOrder(
            paymentStatus: status, paymentId: status == 'unpaid' ? null : 'pay_1');
        final map = CartService.orderToMap(order);
        final restored = CartService.orderFromMap(map);

        expect(restored.paymentStatus, status, reason: 'status $status');
        expect(restored.items.single.baseProductTitle, 'Plain Saree');
        expect(restored.items.single.quantity, 2);
        expect(restored.items.single.lineTotal, 998);
        expect(restored.totalAmount, 998);
      }
    });

    test('infers a sensible payment status for legacy records', () {
      // Legacy online order (payment id present) -> treated as paid.
      final legacyPaid = CartService.orderFromMap({
        'orderId': 'O1',
        'totalAmount': 100,
        'orderDate': DateTime(2026, 1, 1).toIso8601String(),
        'status': 'Print Processing',
        'items': <Map<String, dynamic>>[],
        'paymentMethod': 'UPI / Online',
        'paymentId': 'pay_9',
      });
      expect(legacyPaid.paymentStatus, 'paid');

      // Legacy COD order (no payment id) -> treated as unpaid.
      final legacyCod = CartService.orderFromMap({
        'orderId': 'O2',
        'totalAmount': 100,
        'orderDate': DateTime(2026, 1, 1).toIso8601String(),
        'status': 'Print Processing',
        'items': <Map<String, dynamic>>[],
        'paymentMethod': 'Cash on Delivery',
      });
      expect(legacyCod.paymentStatus, 'unpaid');
    });

    test('cart item size/material/measurements round-trip through maps', () {
      final item = makeItem().copyWith(
        baseProductTitle: 'Plain T-Shirt',
        selectedVariant: 'Black',
        size: 'L',
        material: '100% Cotton',
        measurements: const [
          MapEntry('Fit', 'Regular'),
          MapEntry('Print Area', 'Front'),
        ],
      );
      final restored = CartService.itemFromMap(CartService.itemToMap(item));
      expect(restored.size, 'L');
      expect(restored.material, '100% Cotton');
      expect(restored.measurements.length, 2);
      expect(restored.measurements[0].key, 'Fit');
      expect(restored.measurements[0].value, 'Regular');
      expect(restored.measurements[1].key, 'Print Area');
      expect(restored.measurements[1].value, 'Front');
    });
  });
}
