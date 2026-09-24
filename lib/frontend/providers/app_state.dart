import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/address.dart';
import '../models/cart_item.dart';
import '../models/order_item.dart';
import '../services/cart_service.dart';
import '../services/backend_service.dart';
import '../services/customer_catalogue.dart';

class AppState extends ChangeNotifier {
  final CartService _cartService;

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  String _localeCode = 'en';
  String get localeCode => _localeCode;

  List<CartItem> _cartItems = [];
  List<OrderItem> _orders = [];
  List<BackendProduct> _backendProducts = [];

  StreamSubscription<User?>? _authSub;
  String? _uid;

  List<CartItem> get cartItems => _cartItems;
  List<OrderItem> get orders => _orders;
  List<BackendProduct> get backendProducts => _backendProducts;

  AppState({CartService? cartService})
      : _cartService = cartService ?? CartService() {
    _initFuture = _loadDataFromStorage();
    _setupAuthListener();
    _loadBackendProducts();
  }

  /// Completes once the initial persisted data has been loaded. Useful for
  /// tests (and deterministic startup ordering) before mutating state.
  late final Future<void> _initFuture;
  Future<void> get initialized => _initFuture;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _setupAuthListener() {
    try {
      _authSub =
          FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    } catch (_) {}
  }

  Future<void> _loadBackendProducts() async {
    try {
      final products = await BackendService().fetchProducts();
      if (products.isNotEmpty) {
        _backendProducts = products;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user?.uid == _uid) return;
    _uid = user?.uid;

    if (_uid == null) {
      await _loadDataFromStorage();
      return;
    }

    await _loadUserData(_uid!);
    // Profile may differ between accounts; re-fetch catalogue overrides so a
    // roster change (e.g. admin switch) picks up freshly published products.
    unawaited(CustomerCatalogue.instance.refresh());
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final service = _cartService;
      final cloudCart = await service.fetchCart(uid);
      final cloudOrders = await service.fetchOrders(uid);

      if (cloudCart.isEmpty && cloudOrders.isEmpty) {
        await _migrateLocalToCloud(service, uid);
      } else {
        // The account already has cloud data. Merge rather than clobber so
        // guest items created on this device before sign-in survive; then
        // reload the union so the in-memory snapshot matches Firestore.
        await service.mergeLocalIntoCloud(
            uid, _cartItems, _orders, cloudCart, cloudOrders);
      }
      _cartItems = await service.fetchCart(uid);
      _orders = await service.fetchOrders(uid);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _migrateLocalToCloud(CartService service, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('migrated_to_firestore_v1') ?? false) return;

    if (_cartItems.isNotEmpty || _orders.isNotEmpty) {
      await service.migrateAll(uid, _cartItems, _orders);
    }
    await prefs.setBool('migrated_to_firestore_v1', true);
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> setLocale(String code) async {
    if (_localeCode == code) return;
    _localeCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('localeCode', _localeCode);
  }

  /// Grand total across every cart line (per-unit price × quantity).
  double get totalPrice =>
      _cartItems.fold(0, (sum, item) => sum + item.lineTotal);

  void addToCart(CartItem item) {
    _cartItems.add(item);
    notifyListeners();
    _persistItemAdded(item);
  }

  void updateCartItemQuantity(CartItem item, int quantity) {
    final index = _cartItems.indexOf(item);
    if (index < 0 || quantity < 1) return;
    final updated = item.copyWith(quantity: quantity);
    _cartItems[index] = updated;
    notifyListeners();
    _persistItemUpdated(updated);
  }

  void removeFromCart(CartItem item) {
    _cartItems.remove(item);
    notifyListeners();
    _persistItemRemoved(item.id);
  }

  /// Places an order for the current cart and returns whether it succeeded.
  ///
  /// On success the order is added and the cart cleared. On persistence
  /// failure (e.g. a Firestore write error for a signed-in user) the in-memory
  /// and locally stored cart/orders are rolled back and `false` is returned so
  /// the caller can show an error and let the user retry — the cart is never
  /// cleared for an order that was not actually stored.
  ///
  /// [orderId] is optional; when provided (e.g. generated once before an online
  /// payment) it is reused so that a retry writes to the SAME Firestore doc and
  /// can never create a duplicate order.
  Future<bool> placeOrder({
    Address? shippingAddress,
    String paymentMethod = 'Cash on Delivery',
    String? paymentId,
    String paymentStatus = PaymentStatus.unpaid,
    String? orderId,
  }) async {
    if (_cartItems.isEmpty) return false;

    // Idempotency guard: the payment sheet reuses ONE orderId per checkout so
    // retries/duplicate callbacks target the same Firestore doc. If that order
    // already exists in memory, the order is already placed — return success
    // without creating a duplicate entry.
    if (orderId != null &&
        _orders.any((o) => o.orderId == orderId)) {
      return true;
    }

    final double total =
        _cartItems.fold(0.0, (sum, item) => sum + item.lineTotal);
    final orderedItems = List<CartItem>.from(_cartItems);

    final newOrder = OrderItem(
      orderId: orderId ??
          'ORD${DateTime.now().microsecondsSinceEpoch.toString()}',
      items: List.from(_cartItems),
      totalAmount: total,
      orderDate: DateTime.now(),
      status: 'Pending',
      paymentStatus: paymentStatus,
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      paymentId: paymentId,
    );

    // Optimistically update in-memory + local storage so guests (no Firestore)
    // and the local fallback behave exactly as before.
    _orders.insert(0, newOrder);
    _cartItems.clear();
    notifyListeners();
    await _saveDataToStorage();

    try {
      final ok = await persistOrderToFirestore(newOrder);
      if (!ok) {
        await _rollbackPlaceOrder(newOrder, orderedItems);
        return false;
      }
      return true;
    } catch (_) {
      // Firestore write failed: roll back so the user is not falsely shown a
      // cleared cart / successful order, and can retry.
      await _rollbackPlaceOrder(newOrder, orderedItems);
      return false;
    }
  }

  Future<void> _rollbackPlaceOrder(
      OrderItem newOrder, List<CartItem> orderedItems) async {
    _orders.removeWhere((o) => o.orderId == newOrder.orderId);
    _cartItems.addAll(orderedItems);
    notifyListeners();
    await _saveDataToStorage();
  }

  /// Persists [order] to Firestore when a user is signed in; guests store the
  /// order locally only (returns true). Split out as a seam so tests can
  /// simulate cloud write failures without touching Firestore.
  @visibleForTesting
  Future<bool> persistOrderToFirestore(OrderItem order) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return true;
    await _cartService.commitOrder(uid, order);
    return true;
  }

  Future<void> _persistItemAdded(CartItem item) async {
    await _saveDataToStorage();
    final uid = _uid;
    if (uid != null) {
      try {
        await _cartService.saveCartItem(uid, item);
      } catch (_) {}
    }
  }

  Future<void> _persistItemRemoved(String itemId) async {
    await _saveDataToStorage();
    final uid = _uid;
    if (uid != null) {
      try {
        await _cartService.deleteCartItem(uid, itemId);
      } catch (_) {}
    }
  }

  Future<void> _persistItemUpdated(CartItem item) async {
    await _saveDataToStorage();
    final uid = _uid;
    if (uid != null) {
      try {
        await _cartService.saveCartItem(uid, item);
      } catch (_) {}
    }
  }

  Future<void> _saveDataToStorage() async {
    final prefs = await SharedPreferences.getInstance();

    final cartJson = _cartItems.map(CartService.itemToMap).toList();
    prefs.setString('cart_data', jsonEncode(cartJson));

    final ordersJson = _orders.map(CartService.orderToMap).toList();
    prefs.setString('orders_data', jsonEncode(ordersJson));
  }

  Future<void> _loadDataFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _localeCode = prefs.getString('localeCode') ?? 'en';

    String? cartString = prefs.getString('cart_data');
    if (cartString != null) {
      final decodedCart = jsonDecode(cartString) as List<dynamic>;
      _cartItems = decodedCart
          .map<CartItem>((item) =>
              CartService.itemFromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    String? ordersString = prefs.getString('orders_data');
    if (ordersString != null) {
      final decodedOrders = jsonDecode(ordersString) as List<dynamic>;
      _orders = decodedOrders
          .map<OrderItem>((order) =>
              CartService.orderFromMap(Map<String, dynamic>.from(order)))
          .toList();
    }

    notifyListeners();
  }
}
