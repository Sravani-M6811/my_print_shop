import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/account_details_screen.dart';
import 'package:my_print_shop/frontend/screens/main_navigation_screen.dart';
import 'package:my_print_shop/frontend/screens/design_screen.dart';
import 'package:my_print_shop/frontend/screens/product_detail_screen.dart';
import 'package:my_print_shop/frontend/screens/settings_screen.dart';
import 'package:my_print_shop/ui/widgets/design_card.dart';
import 'package:my_print_shop/frontend/l10n/generated/app_localizations.dart';

Future<void> pumpShell(WidgetTester tester, Size size,
    {AppState? appState}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => appState ?? AppState(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MainNavigationScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> switchTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.text(label),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings screen (req 15-17)', () {
    testWidgets('renders Dark Mode, Language and Account Details entries',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final appState = AppState();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);

      // Dark Mode toggle drives the persisted app theme preference.
      expect(appState.isDarkMode, isFalse);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(appState.isDarkMode, isTrue);

      // Language entry opens the i18n sheet: English only, others honest.
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(find.text('App Language'), findsOneWidget);
      expect(find.text('English'), findsWidgets);
      expect(find.text('Coming soon'), findsWidgets);
      expect(find.text('Selected'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Account Details entry leads to the account details screen.
      await tester.ensureVisible(find.text('Account Details'));
      await tester.tap(find.text('Account Details'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailsScreen), findsOneWidget);
    });

    testWidgets('Account Details shows the guest sign-in entry (no dead end)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: AccountDetailsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not signed in'), findsOneWidget);
      expect(find.text('Sign in with Phone'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Home person icon (req 25)', () {
    testWidgets('switches to the Profile tab instead of doing nothing',
        (tester) async {
      await pumpShell(tester, const Size(900, 1400));

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      // Profile tab is now active.
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('Profile tab opens the Settings screen from the gear icon',
        (tester) async {
      await pumpShell(tester, const Size(900, 1400));

      await switchTab(tester, 'Profile');
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
    });
  });

  group('Global design gallery (req 9)', () {
    testWidgets('Design tab shows ALL categories and category filter chips',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: const MaterialApp(home: DesignScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All Designs'), findsOneWidget);
      expect(find.text('Design Inspiration'), findsOneWidget);
      expect(find.text('Browse by Category'), findsOneWidget);

      // A design card from more than one category is present -> global view.
      final categories = tester
          .widgetList<DesignCard>(find.byType(DesignCard))
          .map((c) => c.product.category)
          .toSet();
      expect(categories.length, greaterThan(1),
          reason: 'global gallery must span several categories');
    });

    testWidgets('category chip narrows the gallery, All restores it',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: const MaterialApp(home: DesignScreen()),
        ),
      );
      await tester.pumpAndSettle();

      int countCards() =>
          tester.widgetList<DesignCard>(find.byType(DesignCard)).length;
      final initial = countCards();
      expect(initial, greaterThan(1));

      final sareesChip = find.descendant(
        of: find.byType(ListView),
        matching: find.widgetWithText(ChoiceChip, 'Sarees'),
      );
      expect(sareesChip, findsWidgets);
      await tester.tap(sareesChip.first);
      await tester.pumpAndSettle();

      final filtered = countCards();
      expect(filtered, lessThan(initial),
          reason: 'choosing a category must remove other category sections');
      expect(tester.takeException(), isNull);

      // Tapping the selected chip again clears the filter -> full gallery.
      await tester.tap(sareesChip.first);
      await tester.pumpAndSettle();
      expect(countCards(), initial);
    });
  });

  group('Sticky product CTA (req 7)', () {
    testWidgets('primary action stays visible without scrolling',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final base = ProductCatalog.baseProducts.first;
      await tester.pumpWidget(
        MaterialApp(home: ProductDetailScreen(product: base)),
      );
      await tester.pumpAndSettle();

      // Hero image and CTA coexistent in the viewport (no scrolling needed).
      final heroTop = tester.getRect(find.byKey(const ValueKey('detail-hero')));
      final cta = tester.getRect(find.text('CHOOSE A DESIGN'));
      expect(cta.top, greaterThan(heroTop.bottom),
          reason: 'sticky CTA must sit below the hero, always in view');
      expect(cta.top, greaterThan(tester.view.physicalSize.height * 0.7),
          reason: 'sticky CTA must live in the bottom action bar');

      // Scrolling keeps the CTA pinned.
      await tester.drag(
          find.byType(ProductDetailScreen), const Offset(0, -600));
      await tester.pumpAndSettle();
      final after = tester.getRect(find.text('CHOOSE A DESIGN'));
      expect(after.top, closeTo(cta.top, 1.0));
      expect(tester.takeException(), isNull);
    });
  });
}
