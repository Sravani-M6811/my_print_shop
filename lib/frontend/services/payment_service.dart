import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';

enum PaymentResultStatus { paid, cancelled, failed }

class PaymentResult {
  final PaymentResultStatus status;
  final String? paymentId;

  /// Razorpay order id and signature from the success callback, used to verify
  /// the payment server-side before an order is marked paid.
  final String? orderId;
  final String? signature;
  final String? message;

  const PaymentResult({
    required this.status,
    this.paymentId,
    this.orderId,
    this.signature,
    this.message,
  });
}

/// Wraps the Razorpay Checkout SDK behind one async call.
///
/// SECURITY: only the PUBLIC Key ID may live in client code. The Key SECRET
/// must never be embedded in the app - payment signature verification would
/// be a backend concern (out of scope here).
///
/// KEY CONFIGURATION (the SDK needs a public key id at checkout time):
///   flutter run --dart-define=RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxx
/// The defaultValue below is Razorpay's own public sample TEST key id so
/// test-mode checkout works out of the box. It is NOT a secret. Replace it
/// via --dart-define (test or live key id) for real usage.
class PaymentService {
  static const String _keyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_1DP5mmOlF5G5ag', // PUBLIC sample TEST key id
  );

  Razorpay? _razorpay;
  Completer<PaymentResult>? _completer;

  /// Opens Razorpay Checkout and resolves exactly once with the outcome.
  ///
  /// When [serverOrderId] is provided the Razorpay Checkout is linked to a
  /// server-authoritative order created via `/api/razorpay/order`. This
  /// prevents the client from tampering with the amount since the amount
  /// is locked server-side.
  Future<PaymentResult> startPayment({
    required double amountInRupees,
    String description = '',
    String? contact,
    String? email,
    String? serverOrderId,
  }) async {
    if (_completer != null && !_completer!.isCompleted) {
      return const PaymentResult(
          status: PaymentResultStatus.failed,
          message: 'A payment is already in progress.');
    }

    _completer = Completer<PaymentResult>();
    _razorpay = Razorpay();

    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    try {
      final checkoutOptions = <String, dynamic>{
        'key': _keyId,
        'amount': (amountInRupees * 100).round(), // paise
        'name': 'My Print Shop',
        'description': description,
        'prefill': {'contact': contact ?? '', 'email': email ?? ''},
        'theme': {'color': '#6C5CE7'},
      };
      if (serverOrderId != null && serverOrderId.isNotEmpty) {
        checkoutOptions['order_id'] = serverOrderId;
      }
      _razorpay!.open(checkoutOptions);
    } catch (e) {
      _finish(PaymentResult(
          status: PaymentResultStatus.failed,
          message: 'Could not open payment gateway: $e'));
    }

    final result = await _completer!.future;
    _teardown();
    return result;
  }

  void _onSuccess(PaymentSuccessResponse response) {
    _finish(PaymentResult(
        status: PaymentResultStatus.paid,
        paymentId: response.paymentId,
        orderId: response.orderId,
        signature: response.signature));
  }

  void _onError(PaymentFailureResponse response) {
    if (response.code == 2) {
      // Code 2 = user closed/cancelled the checkout UI.
      _finish(const PaymentResult(
          status: PaymentResultStatus.cancelled,
          message: 'Payment cancelled.'));
    } else {
      _finish(PaymentResult(
          status: PaymentResultStatus.failed,
          message:
              response.message ?? 'Payment failed (code ${response.code}).'));
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    // External wallet selection does NOT end the checkout: the payment sheet
    // stays open and Razorpay later reports the real outcome via
    // EVENT_PAYMENT_SUCCESS or EVENT_PAYMENT_ERROR. Finishing here as
    // "cancelled" would tear down the handlers and silently drop that success
    // event — a captured wallet payment would never reach the order. So this
    // event is intentionally ignored.
  }

  void _finish(PaymentResult result) {
    if (_completer?.isCompleted == false) _completer!.complete(result);
  }

  void _teardown() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
