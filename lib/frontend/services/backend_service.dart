import 'dart:convert';
import 'package:http/http.dart' as http;

/// Product model matching the Node.js backend /api/products response.
class BackendProduct {
  final int id;
  final String name;
  final double pricePerUnit;
  final String type;

  const BackendProduct({
    required this.id,
    required this.name,
    required this.pricePerUnit,
    required this.type,
  });

  factory BackendProduct.fromJson(Map<String, dynamic> json) {
    return BackendProduct(
      id: json['id'] as int,
      name: json['name'] as String,
      pricePerUnit: (json['pricePerUnit'] as num).toDouble(),
      type: json['type'] as String,
    );
  }
}

/// Thin client for the Print Shop Node.js backend.
///
/// Every public method returns `null` (or an empty list) when the backend is
/// unreachable so the rest of the app can fall back to its existing Firebase /
/// local data without disruption.
class BackendService {
  /// Base URL override via `--dart-define=BACKEND_URL=...`.
  ///
  /// Chrome / desktop default: http://localhost:5000
  /// Android emulator:         http://10.0.2.2:5000
  /// LAN device:               http://`host-ip`:5000
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:5000',
  );

  /// Injectable so tests can stub the network at the payment-verification
  /// boundary. Defaults to a real HTTP client.
  final http.Client _client;

  BackendService({http.Client? client}) : _client = client ?? http.Client();

  // ── Products ──────────────────────────────────────────────────────────

  /// Fetch the product catalogue from GET /api/products.
  Future<List<BackendProduct>> fetchProducts() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/products'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] is List) {
          return (body['data'] as List)
              .map((e) => BackendProduct.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Orders (admin read-only – the Flutter app writes via Firestore) ──

  /// Fetch all orders from GET /api/orders.
  Future<List<Map<String, dynamic>>> fetchOrders() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/orders'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['orders'] is List) {
          return (body['orders'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Place an order via POST /api/orders (fire-and-forget, non-blocking).
  ///
  /// Returns the server response map on success, `null` on failure.
  /// This is a *secondary* channel – the primary order pipeline remains
  /// Firestore (see AppState.placeOrder).
  Future<Map<String, dynamic>?> createOrder({
    required String customerName,
    required String phone,
    required int productId,
    required int quantity,
    String? fileUrl,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/orders'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'customerName': customerName,
              'phone': phone,
              'productId': productId,
              'quantity': quantity,
              'fileUrl': ?fileUrl,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Update order status via PATCH /api/admin/orders/:id.
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await _client
          .patch(
            Uri.parse('$baseUrl/api/admin/orders/$orderId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Razorpay (server-authoritative order creation + verification) ────────

  /// Creates a server-authoritative Razorpay order so the amount cannot be
  /// tampered with by the client. Returns `{orderId, amount}` where amount
  /// is in paise, or `null` when the backend / Razorpay is unreachable.
  Future<Map<String, dynamic>?> createRazorpayOrder({
    required int amountPaise,
    String? receipt,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/razorpay/order'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'amountPaise': amountPaise,
              'receipt': ?receipt,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return body;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Verifies a Razorpay payment signature against the server-side key secret.
  ///
  /// Returns a [PaymentVerification]:
  ///   * [PaymentVerification.verified]      - signature matched (paid, verified).
  ///   * [PaymentVerification.unverified]    - backend reachable and fought it,
  ///                                           signature did NOT match.
  ///   * [PaymentVerification.unavailable]   - backend unreachable / secret not
  ///                                           configured. The payment can NOT be
  ///                                           confirmed, so it must stay pending.
  Future<PaymentVerification> verifyRazorpayPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    double? amount,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/razorpay/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'paymentId': paymentId,
              'orderId': orderId,
              'signature': signature,
              'amount': amount,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final available = body['verificationAvailable'] ?? false;
        final verified = body['verified'] ?? false;
        if (available) {
          return verified
              ? PaymentVerification.verified
              : PaymentVerification.unverified;
        }
        return PaymentVerification.unavailable;
      }
      return PaymentVerification.unavailable;
    } catch (_) {
      return PaymentVerification.unavailable;
    }
  }

  /// Quick health-check: can the backend be reached?
  Future<bool> isAvailable() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/products'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── AI Assistant (via local Ollama) ────────────────────────────────────

  /// Send a chat message to the print-shop assistant.
  ///
  /// `history` is an optional list of `{role, content}` pairs (system excluded)
  /// that provide context for follow-up questions.
  ///
  /// Returns the assistant's reply on success, or `null` when the backend or
  /// the local Ollama instance is unreachable.
  Future<AssistantReply?> chatWithAssistant(
    String message, {
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/assistant'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': message, 'history': history}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return AssistantReply(
            reply: body['reply'] as String? ?? '',
            model: body['model'] as String?,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Check whether the assistant backend + Ollama are usable without sending
  /// a message (uses a lightweight prompt).
  Future<bool> isAssistantAvailable() async {
    final reply = await chatWithAssistant('ping');
    return reply != null && reply.reply.isNotEmpty;
  }
}

/// Result of an assistant conversation turn.
class AssistantReply {
  /// The assistant's text reply.
  final String reply;

  /// The Ollama model that produced the reply (if the backend reports it).
  final String? model;

  const AssistantReply({required this.reply, this.model});
}

/// Outcome of a server-side Razorpay verification call.
enum PaymentVerification {
  /// Signature verified server-side using the key secret — order can be marked paid.
  verified,

  /// Backend reachable but the signature did not match — do NOT mark paid.
  unverified,

  /// Backend unreachable or key secret not configured — cannot confirm; keep pending.
  unavailable,
}
