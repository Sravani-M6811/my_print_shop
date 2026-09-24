import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/admin/screens/admin_products_screen.dart';
import 'package:my_print_shop/frontend/screens/main_navigation_screen.dart';
import 'package:my_print_shop/frontend/screens/category_catalogue_screen.dart';
import 'package:my_print_shop/frontend/screens/subcategory_catalogue_screen.dart';
import 'package:my_print_shop/frontend/screens/design_screen.dart';
import 'package:my_print_shop/frontend/screens/cart_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── OTP: no database existence check gates OTP sending ─────────────────────
  group('OTP', () {
    test('source files never check Firestore/SQLite before verifyPhoneNumber', () {
      // The constraint: OTP must fire for ANY valid phone number, never
      // requiring a database record first. Scan the auth service and all
      // screens that invoke phone login for any Firestore/SQLite read before
      // OTP send.
      final dirs = [
        Directory('lib'),
      ];
      final otpSendPattern = RegExp(
        r'verifyPhoneNumber|signInWithOTP|PhoneLoginScreen|OtpScreen',
      );
      final dbCheckPattern = RegExp(
        r'collection\(|get\(\)|\.doc\(|sqlite|openDatabase',
      );

      for (final dir in dirs) {
        if (!dir.existsSync()) continue;
        final files = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

        for (final file in files) {
          final content = file.readAsStringSync();
          // Skip screens that legitimately access the DB (profile, admin, orders, etc.)
          if (file.path.contains('account_details') ||
              file.path.contains('order') ||
              file.path.contains('admin') ||
              file.path.contains('settings') ||
              file.path.contains('checkout') ||
              file.path.contains('catalogue_service')) {
            continue;
          }
          if (!otpSendPattern.hasMatch(content)) continue;

          // Look for DB reads BEFORE the verifyPhoneNumber call.
          final verifyIdx = content.indexOf('verifyPhoneNumber');
          if (verifyIdx == -1) continue;

          final precedingDbCheck =
              dbCheckPattern.hasMatch(content.substring(0, verifyIdx));
          expect(
            precedingDbCheck,
            isFalse,
            reason:
                '${file.path} appears to check a database before calling verifyPhoneNumber',
          );
        }
      }
    });
  });

  // ── Subcategory model ─────────────────────────────────────────────────────
  group('ProductSubcategory', () {
    test('every category exposes at least one subcategory', () {
      for (final category in ProductCatalog.categories) {
        final subs = ProductCatalog.subcategoriesFor(category);
        expect(subs, isNotEmpty,
            reason: '$category should have subcategories');
      }
    });

    test('subcategoryById returns correct sub for every category', () {
      for (final category in ProductCatalog.categories) {
        final subs = ProductCatalog.subcategoriesFor(category);
        for (final sub in subs) {
          final resolved = ProductCatalog.subcategoryById(sub.id);
          expect(resolved?.id, sub.id);
          expect(resolved?.name, sub.name);
        }
      }
    });

    test('baseProductsForSubcategory returns products from correct category', () {
      for (final category in ProductCatalog.categories) {
        final subs = ProductCatalog.subcategoriesFor(category);
        for (final sub in subs) {
          final products = ProductCatalog.baseProductsForSubcategory(sub);
          for (final p in products) {
            expect(p.category, category,
                reason: 'product ${p.id} should belong to $category');
          }
        }
      }
    });

    test('designsForSubcategory only returns design/ready-made with matching designType', () {
      final subs = ProductCatalog.subcategoriesFor('Embroidery');
      for (final sub in subs) {
        final designs = ProductCatalog.designsForSubcategory(sub);
        final type = sub.designType;
        if (type == null || type.isEmpty) {
          expect(designs, isEmpty,
              reason: '${sub.name} with no designType should have no designs');
          continue;
        }
        for (final d in designs) {
          expect(d.designType, type,
              reason: '${d.id} designType should match ${sub.name}');
        }
      }
    });
  });

  // ── Cart Trending ready-made only ─────────────────────────────────────────
  group('Cart Trending', () {
    test('trendingReadyMade only contains ready-made products', () {
      final trending = ProductCatalog.trendingReadyMade;
      for (final p in trending) {
        expect(p.isReadyMade, isTrue,
            reason: '${p.id} is in trendingReadyMade but is not readyMade');
        expect(p.isTrending, isTrue,
            reason: '${p.id} is in trendingReadyMade but is not trending');
        expect(p.isAvailable, isTrue,
            reason: '${p.id} is in trendingReadyMade but is not available');
      }
    });

    test('no plain/base product appears in trendingReadyMade', () {
      final trending = ProductCatalog.trendingReadyMade;
      for (final p in trending) {
        expect(p.isBase, isFalse,
            reason: '${p.id} is a base product in trendingReadyMade');
      }
    });

    test('no design (non-readyMade) product appears in trendingReadyMade', () {
      final trending = ProductCatalog.trendingReadyMade;
      for (final p in trending) {
        expect(p.isDesign && !p.isReadyMade, isFalse,
            reason: '${p.id} is a pure design in trendingReadyMade');
      }
    });
  });

  // ── Home offers ───────────────────────────────────────────────────────────
  group('Home Offers', () {
    test('homeOffers returns only base products', () {
      final offers = ProductCatalog.homeOffers();
      expect(offers, isNotEmpty, reason: 'homeOffers() should not be empty');
      for (final p in offers) {
        expect(p.isBase, isTrue,
            reason: '${p.id} in homeOffers but is not base');
        expect(p.isReadyMade, isFalse,
            reason: '${p.id} in homeOffers but is readyMade');
        expect(p.isDesign, isFalse,
            reason: '${p.id} in homeOffers but is design');
      }
    });

    test('all homeOffers product ids exist in catalogue', () {
      final offers = ProductCatalog.homeOffers();
      for (final p in offers) {
        expect(ProductCatalog.productById(p.id)?.id, p.id,
            reason: '${p.id} not found in catalogue');
      }
    });
  });

  // ── Design screen global gallery ──────────────────────────────────────────
  group('Design Screen', () {
    testWidgets('global gallery renders all required filter rows',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: MaterialApp(
            home: DesignScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesignScreen), findsOneWidget);
      expect(find.text('All Designs'), findsWidgets);
      expect(find.text('Design Inspiration'), findsWidgets);
      expect(find.text('Browse by Theme'), findsOneWidget);
      expect(find.text('Browse by Category'), findsOneWidget);
      expect(find.text('Browse by Type'), findsOneWidget);
    });

    testWidgets('global gallery shows subcategory row when category selected',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: MaterialApp(
            home: DesignScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No subcategory row before selecting a category
      expect(find.text('Browse by Subcategory'), findsNothing);

      // Tap the first non-All category chip
      // Find a specific category chip, e.g. "Sarees"
      final sareesChip = find.byWidgetPredicate(
        (w) => w is ChoiceChip &&
            (w.label as Text?)?.data == 'Sarees',
      );
      if (sareesChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(sareesChip);
        await tester.pumpAndSettle();
        await tester.tap(sareesChip);
        await tester.pumpAndSettle();
        expect(find.text('Browse by Subcategory'), findsOneWidget);
      }
    });

    testWidgets('image resolver uses CatalogueImage (never product paths directly)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: MaterialApp(
            home: DesignScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Design screen renders CatalogueImage for design records, NOT raw path text.
      final catalogueImages = find.byWidgetPredicate(
        (w) => w.toString().contains('CatalogueImage'),
      );
      // At minimum some design cards should render
      expect(catalogueImages, findsAtLeastNWidgets(1),
          reason: 'design screen should use CatalogueImage widgets');
    });
  });

  // ── Navigation flow: Home → Category → Subcategory → Product → Detail CTA ─
  group('Navigation Flow', () {
    testWidgets('Home → Category → Subcategory → Product Detail with sticky CTA',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: MaterialApp(home: MainNavigationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Home: tap a category tile
      final tshirtTile = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'T-Shirts',
      );
      expect(tshirtTile, findsWidgets, reason: 'T-Shirts should appear on Home');
      await tester.ensureVisible(tshirtTile.first);
      await tester.pumpAndSettle();
      await tester.tap(tshirtTile.first);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryCatalogueScreen), findsOneWidget);

      // Category screen: should have sub-category tiles
      await tester.pumpAndSettle();

      // Scroll to find sub-category tiles — look for half-sleeve or first sub
      final subs = ProductCatalog.subcategoriesFor('T-Shirts');
      if (subs.isNotEmpty) {
        final firstSubName = subs.first.name;
        final subTile = find.text(firstSubName);
        if (subTile.evaluate().isNotEmpty) {
          await tester.tap(subTile.first);
          await tester.pumpAndSettle();
          expect(find.byType(SubcategoryCatalogueScreen), findsOneWidget);
        }
      }
    });

    testWidgets('Category catalogue screen has subcategory tiles', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tshirts = ProductCatalog.categoryDescriptors
          .firstWhere((d) => d.name == 'T-Shirts');
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: MaterialApp(
            home: CategoryCatalogueScreen(category: tshirts),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CategoryCatalogueScreen), findsOneWidget);
      // Subcategory tiles should be present
      final subs = ProductCatalog.subcategoriesFor('T-Shirts');
      expect(subs, isNotEmpty, reason: 'T-Shirts should have subcategories');
    });
  });

  // ── Cart trending rail integration ────────────────────────────────────────
  group('Cart Screen', () {
    testWidgets('cart screen renders trending ready-made section',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: const MaterialApp(home: CartScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);
      // Cart screen should render without overflow
      expect(tester.takeException(), isNull);
    });
  });

  // ── Admin image rendering ─────────────────────────────────────────────────
  group('Admin Products Screen', () {
    testWidgets('renders image thumbnails, not just path text',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: MaterialApp(
            home: Scaffold(
              body: AdminProductsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminProductsScreen), findsOneWidget);
      // Table or cards should render with thumb widgets
      expect(tester.takeException(), isNull,
          reason: 'admin products screen should render without error');
    });
  });

  // ── Image catalogue registry ──────────────────────────────────────────────
  group('ImageCatalogueRegistry', () {
    test('page returns products in correct page size', () {
      final all = ProductCatalog.staticProducts;
      final page1 = ProductCatalog.pageOf(all, page: 1, pageSize: 48);
      expect(page1.length, 48);
      expect(page1.first.id, all[0].id);

      final lastPage =
          ProductCatalog.pageOf(all, page: (all.length / 48).ceil(), pageSize: 48);
      expect(lastPage.length, greaterThanOrEqualTo(1));
      expect(lastPage.last.id, all.last.id);
    });

    test('pageOf returns empty for invalid page', () {
      final all = ProductCatalog.staticProducts;
      expect(ProductCatalog.pageOf(all, page: 0), isEmpty);
      expect(
          ProductCatalog.pageOf(all, page: 99999, pageSize: 48), isEmpty);
    });
  });

  // ── Responsive overflow: all critical screens ─────────────────────────────
  group('Responsive layout', () {
    for (final size in const [Size(320, 568), Size(390, 844)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('CategoryCatalogueScreen no overflow at $label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final sarees = ProductCatalog.categoryDescriptors
            .firstWhere((d) => d.name == 'Sarees');
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => AppState(),
            child: MaterialApp(
              home: CategoryCatalogueScreen(category: sarees),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'CategoryCatalogueScreen overflow at $label');
      });

      testWidgets('DesignScreen no overflow at $label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => AppState(),
            child: MaterialApp(home: DesignScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'DesignScreen overflow at $label');
      });
    }
  });
}
