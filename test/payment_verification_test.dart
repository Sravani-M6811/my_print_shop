import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_print_shop/frontend/services/backend_service.dart';

BackendService _backendWith(
        Future<http.Response> Function(http.Request) handler) =>
    BackendService(client: MockClient(handler));

void main() {
  group('BackendService.verifyRazorpayPayment', () {
    test('returns verified only when the server confirms the signature', () async {
      http.Request? captured;
      final service = _backendWith((req) async {
        captured = req;
        return http.Response(
          '{"success":true,"verificationAvailable":true,"verified":true}',
          200,
        );
      });

      final result = await service.verifyRazorpayPayment(
        paymentId: 'pay_abc',
        orderId: 'ord_123',
        signature: 'sig',
        amount: 499,
      );

      expect(result, PaymentVerification.verified);

      // The client forwards the payment metadata to the server — no state is
      // fabricated on the client side.
      final body = captured!.body;
      expect(body, contains('pay_abc'));
      expect(body, contains('ord_123'));
      expect(body, contains('sig'));
      expect(body, contains('499'));
    });

    test('returns unverified when the signature does not match', () async {
      final service = _backendWith((req) async =>
          http.Response('{"success":true,"verificationAvailable":true,"verified":false}', 200));

      expect(
        await service.verifyRazorpayPayment(
            paymentId: 'p', orderId: 'o', signature: 'bad'),
        PaymentVerification.unverified,
      );
    });

    test('returns unavailable when verification is not configured server-side',
        () async {
      final service = _backendWith((req) async =>
          http.Response('{"success":true,"verificationAvailable":false}', 200));

      expect(
        await service.verifyRazorpayPayment(
            paymentId: 'p', orderId: 'o', signature: 'x'),
        PaymentVerification.unavailable,
      );
    });

    test('returns unavailable on server errors and network failures', () async {
      final serverError = _backendWith((req) async =>
          http.Response('{"success":false}', 500));
      expect(
        await serverError.verifyRazorpayPayment(
            paymentId: 'p', orderId: 'o', signature: 'x'),
        PaymentVerification.unavailable,
      );

      final offline = _backendWith((req) async =>
          throw http.ClientException('offline'));
      expect(
        await offline.verifyRazorpayPayment(
            paymentId: 'p', orderId: 'o', signature: 'x'),
        PaymentVerification.unavailable,
      );
    });
  });
}
