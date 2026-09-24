import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/main_navigation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App builds and renders the main navigation shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    // Use TestApp wrapper to provide theme and prevent image asset errors
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => AppState(),
          child: const MainNavigationScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify the bottom navigation renders
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.home_filled), findsWidgets);
    expect(find.byIcon(Icons.palette_rounded), findsWidgets);
    expect(find.byIcon(Icons.shopping_bag_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsWidgets);
  });
}
