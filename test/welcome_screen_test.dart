import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/welcome_screen.dart';
import 'package:my_print_shop/frontend/screens/main_navigation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Continue as Guest navigates without a deactivated-context error',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Welcome screen renders.
    expect(find.text('Welcome to MY PRINT SHOP'), findsOneWidget);

    // Tapping "Continue as Guest" used to call Provider.of(context) inside the
    // route builder after this route was deactivated, throwing
    // "Looking up a deactivated widget's ancestor is unsafe." on Web.
    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();

    // Navigation completes to MainNavigationScreen with no uncaught error.
    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
