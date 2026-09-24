import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_print_shop/frontend/models/cart_item.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CartItem item({String id = '1', double price = 100, int quantity = 1}) =>
      CartItem(
        id: id,
        title: 'Tee',
        category: 'T-Shirts',
        customText: 'Design',
        selectedSide: 'Front',
        fontFamily: 'Sans-Serif',
        price: price,
        color: const Color(0xFFFFFFFF),
        quantity: quantity,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('totalPrice sums line totals', () {
    final state = AppState();
    state.addToCart(item(id: 'a', price: 100, quantity: 2));
    state.addToCart(item(id: 'b', price: 50));
    expect(state.totalPrice, 250);
  });

  test('updateCartItemQuantity recomputes line total', () {
    final state = AppState();
    final cartItem = item(price: 100);
    state.addToCart(cartItem);
    state.updateCartItemQuantity(cartItem, 5);
    expect(state.cartItems.single.quantity, 5);
    expect(state.cartItems.single.lineTotal, 500);
    expect(state.totalPrice, 500);
  });

  test('placeOrder moves cart items to orders and clears the cart', () async {
    final state = AppState();
    await state.initialized;
    state.addToCart(item(price: 100, quantity: 2));
    final ok = await state.placeOrder();

    expect(ok, isTrue);
    expect(state.cartItems, isEmpty);
    expect(state.orders, hasLength(1));
    expect(state.orders.first.totalAmount, 200);
    expect(state.orders.first.status, 'Pending');
    // COD is the default (unpaid) so payment status is not 'paid'.
    expect(state.orders.first.paymentStatus, 'unpaid');
    expect(state.orders.first.paymentMethod, 'Cash on Delivery');
  });

  test('placeOrder returns false when the cart is empty', () async {
    final state = AppState();
    expect(await state.placeOrder(), isFalse);
    expect(state.orders, isEmpty);
  });

  test('placeOrder with quantity>1 charges unit x quantity (not unit)', () async {
    final state = AppState();
    await state.initialized;
    state.addToCart(item(id: 'a', price: 499, quantity: 2));
    state.addToCart(item(id: 'b', price: 999));
    final ok = await state.placeOrder();

    expect(ok, isTrue);
    // 499*2 + 999*1 = 1997, NOT 499 + 999.
    expect(state.orders.single.totalAmount, 1997);
    expect(state.orders.single.items.map((i) => i.lineTotal), [998, 999]);
  });

  test('placeOrder records paid/pending payment status from the caller',
      () async {
    final state = AppState();
    await state.initialized;
    state.addToCart(item(price: 100));
    await state.placeOrder(
      paymentMethod: 'UPI / Online',
      paymentId: 'pay_123',
      paymentStatus: 'paid',
    );
    expect(state.orders.single.paymentStatus, 'paid');
    expect(state.orders.single.paymentId, 'pay_123');

    state.addToCart(item(price: 100));
    await state.placeOrder(
      paymentMethod: 'UPI / Online',
      paymentId: 'pay_456',
      paymentStatus: 'pending',
    );
    expect(state.orders.first.paymentStatus, 'pending');
    expect(state.orders, hasLength(2));
  });

  test('placeOrder keeps the provided orderId (idempotent retry target)',
      () async {
    final state = AppState();
    await state.initialized;
    state.addToCart(item(price: 100));
    await state.placeOrder(orderId: 'ORD_FIXED');
    expect(state.orders.single.orderId, 'ORD_FIXED');
  });

  test('cart item base product + design are retained through placeOrder',
      () async {
    final state = AppState();
    await state.initialized;
    state.addToCart(item(
      id: 'x',
      price: 499,
      quantity: 2,
    ).copyWith(baseProductTitle: 'Plain Saree'));

    await state.placeOrder();
    final orderItem = state.orders.single.items.single;
    expect(orderItem.baseProductTitle, 'Plain Saree');
    expect(orderItem.title, 'Tee'); // design title preserved
    expect(orderItem.quantity, 2);
    expect(orderItem.lineTotal, 998);
  });

  test('selected colour/variant survives through placeOrder into the order',
      () async {
    final state = AppState();
    await state.initialized;
    state.addToCart(item(id: 'x', price: 399).copyWith(
        baseProductTitle: 'Plain T-Shirt', selectedVariant: 'Black'));

    await state.placeOrder();
    final orderItem = state.orders.single.items.single;
    expect(orderItem.baseProductTitle, 'Plain T-Shirt');
    expect(orderItem.selectedVariant, 'Black');
  });

  test('print position + uploaded artwork + baseProductId survive placeOrder',
      () async {
    final state = AppState();
    await state.initialized;
    state.addToCart(item(id: 'p', price: 599).copyWith(
      baseProductTitle: 'Plain Mug',
      baseProductId: 'mug-1',
      printPosition: 'Back',
      uploadedDesignPath: 'uploads/me.png',
    ));

    await state.placeOrder();
    final orderItem = state.orders.single.items.single;
    expect(orderItem.baseProductId, 'mug-1');
    expect(orderItem.printPosition, 'Back');
    expect(orderItem.uploadedDesignPath, 'uploads/me.png');
  });

  test('size + material + measurements survive placeOrder into the order',
      () async {
    final state = AppState();
    await state.initialized;
    state.addToCart(item(id: 's', price: 399).copyWith(
      baseProductTitle: 'Plain T-Shirt',
      selectedVariant: 'Black',
      size: 'L',
      material: '100% Cotton',
      measurements: const [
        MapEntry('Fit', 'Regular'),
        MapEntry('Print Area', 'Front'),
      ],
    ));

    await state.placeOrder();
    final orderItem = state.orders.single.items.single;
    expect(orderItem.size, 'L');
    expect(orderItem.material, '100% Cotton');
    expect(orderItem.measurements, const [
      MapEntry('Fit', 'Regular'),
      MapEntry('Print Area', 'Front'),
    ]);
  });
}
