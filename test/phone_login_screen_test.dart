import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_print_shop/frontend/screens/phone_login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phone login shows error for empty phone', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneLoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send OTP'));
    await tester.pump();

    expect(find.text('Please enter your mobile number.'), findsOneWidget);
  });

  testWidgets('Phone login rejects missing country code', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneLoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pump();

    expect(
      find.text('Phone number must start with country code (e.g. +91).'),
      findsOneWidget,
    );
  });

  testWidgets('Phone login rejects invalid short numbers', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneLoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '+91');
    await tester.tap(find.text('Send OTP'));
    await tester.pump();

    expect(
      find.text('Please enter a valid phone number with country code.'),
      findsOneWidget,
    );
  });
}
