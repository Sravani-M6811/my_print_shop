import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/design_customize_screen.dart';
import 'package:my_print_shop/frontend/screens/design_screen.dart';
import 'package:my_print_shop/frontend/services/pexels_service.dart';
import 'package:my_print_shop/ui/widgets/design_card.dart';

/// Verifies the ORIGINAL Design Screen requirements for every category:
///   * each category gallery renders ONLY that category's designs (no leakage),
///   * design cards show real images (never the silent placeholder),
///   * every design image exists in the bundle and a sample decodes,
///   * search accepts input, preserves the active category, filters local
///     designs, and tops them up with a live category-aware Pexels query
///     (loading -> results / no-results / errors with retry),
///   * selecting a design opens Customize exactly once and back returns to the
///     exact previous screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const categories = [
    'Sarees',
    'Saree Borders',
    'T-Shirts',
    'Mugs',
    'Posters',
    'Embroidery',
    'Cardboard',
    'Glass Art',
  ];

  Future<void> proveImageDecodes(String key) async {
    final stream = AssetImage(key).resolve(ImageConfiguration.empty);
    final completer = Completer<void>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool syncCall) {
        info.image.dispose();
        completer.complete();
      },
      onError: (Object error, StackTrace? stackTrace) {
        completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('decode timed out for $key'),
    );
    stream.removeListener(listener);
  }

  Future<void> pumpDesign(WidgetTester tester, String category) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(home: DesignScreen(initialCategory: category)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(DesignScreen), const Offset(0, -350));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  test(
    'every design image across the 8 categories exists on disk',
    () {
      final missing = <String>[];
      for (final category in categories) {
        for (final p in ProductCatalog.productsForCategory(category)) {
          if (!File(p.imagePath).existsSync()) {
            missing.add('${p.id}: ${p.imagePath}');
          }
        }
      }
      if (missing.isNotEmpty) {
        fail('${missing.length} missing design images:\n'
            '${missing.take(20).join('\n')}');
      }
    },
  );

  test(
    'a decodable sample of every category renders through the real loader',
    () async {
      for (final category in categories) {
        final designs = ProductCatalog.productsForCategory(category);
        expect(designs, isNotEmpty, reason: '$category must define designs');
        for (final d in designs.take(4)) {
          await proveImageDecodes(d.imagePath);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  for (final category in categories) {
    testWidgets('$category gallery shows only its own designs, no placeholders',
        (tester) async {
      await pumpDesign(tester, category);
      await tester.pumpAndSettle();

      expect(find.text('$category Designs'), findsWidgets);

      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(DesignScreen), const Offset(0, -350));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.byType(DesignCard), findsWidgets,
          reason: '$category must render design cards');
      for (final card
          in tester.widgetList<DesignCard>(find.byType(DesignCard))) {
        expect(card.product.category, category,
            reason: '$category gallery leaked ${card.product.category} '
                'design ${card.product.id}');
      }
      expect(find.byIcon(Icons.image_not_supported), findsNothing,
          reason: '$category must not fall back to the placeholder icon');
    });
  }

  testWidgets(
      'search filters the active category and tops up with live Pexels images',
      (tester) async {
    final service = PexelsService.instance;
    service.httpClientOverride = MockClient((request) async {
      // Category-aware query built from user input + category term.
      expect(request.url.queryParameters['query'], 'wedding cardboard');
      return http.Response(
        jsonEncode({
          'photos': [
            {
              'id': 1,
              'alt': 'Wedding Standee Decor',
              'photographer': 'Photo Co',
              'src': {
                'large': 'https://images.pexels.com/w1.jpg',
                'landscape': 'https://images.pexels.com/w1b.jpg',
              },
            },
            {
              'id': 2,
              'alt': 'Welcome Board',
              'photographer': 'P2',
              'src': {'landscape': 'https://images.pexels.com/w2.jpg'},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    service.apiKeyOverride = 'TEST_KEY';
    addTearDown(() {
      service.httpClientOverride = null;
      service.apiKeyOverride = null;
    });

    await pumpDesign(tester, 'Cardboard');
    await tester.enterText(find.byType(TextField), 'wedding');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Local category-scoped results only.
    expect(find.text('Wedding Invitation Template'), findsOneWidget);
    final results =
        tester.widgetList<DesignCard>(find.byType(DesignCard)).toList();
    expect(results, isNotEmpty);
    for (final card in results) {
      expect(card.product.category, 'Cardboard',
          reason: 'search leaked ${card.product.category}');
    }

    await reveal(tester, find.text('Pexels Inspiration'));
    expect(find.text('2 images'), findsOneWidget);
    await tester.ensureVisible(find.text('Wedding Standee Decor'));
    await tester.tap(find.text('Wedding Standee Decor'));
    await tester.pumpAndSettle();

    // Selecting a Pexels design opens Customize exactly once.
    expect(find.byType(DesignCustomizeScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DesignScreen), findsOneWidget);

    // Clearing the search returns to the category gallery.
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('Pexels Inspiration'), findsNothing);
    expect(find.text('Cardboard Designs'), findsWidgets);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
  });

  testWidgets('search shows a loading state, surfaces network errors, retries',
      (tester) async {
    final service = PexelsService.instance;
    var calls = 0;
    service.httpClientOverride = MockClient((request) async {
      calls++;
      if (calls == 1) throw http.ClientException('connection refused');
      return http.Response(
        jsonEncode({
          'photos': [
            {
              'id': 9,
              'alt': 'Zebra Foo Tshirt',
              'photographer': 'P',
              'src': {'large': 'https://images.pexels.com/z.jpg'},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    service.apiKeyOverride = 'TEST_KEY';
    addTearDown(() {
      service.httpClientOverride = null;
      service.apiKeyOverride = null;
    });

    await pumpDesign(tester, 'T-Shirts');
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();

    // Loading state while the debounced request is in flight.
    expect(find.textContaining('Searching Pexels for'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await reveal(tester, find.text('Retry'));
    expect(find.textContaining('Could not reach Pexels'), findsOneWidget);
    expect(find.textContaining('No designs in T-Shirts match'), findsOneWidget);

    // Retry succeeds and shows the photo.
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Pexels Inspiration'));
    expect(find.text('Zebra Foo Tshirt'), findsOneWidget);
  });

  testWidgets('search shows a no-results state when both sources are empty',
      (tester) async {
    final service = PexelsService.instance;
    service.httpClientOverride = MockClient((request) async =>
        http.Response(jsonEncode({'photos': <Object>[]}), 200,
            headers: {'content-type': 'application/json'}));
    service.apiKeyOverride = 'TEST_KEY';
    addTearDown(() {
      service.httpClientOverride = null;
      service.apiKeyOverride = null;
    });

    await pumpDesign(tester, 'T-Shirts');
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await reveal(tester, find.text('No Pexels images found for "zzz".'));
    expect(find.text('No Pexels images found for "zzz".'), findsOneWidget);
    expect(find.textContaining('No designs in T-Shirts match'), findsOneWidget);
  });

  testWidgets('tapping a local design opens Customize once; back returns',
      (tester) async {
    await pumpDesign(tester, 'T-Shirts');
    final card = find.byType(DesignCard).first;
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byType(DesignCustomizeScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DesignCustomizeScreen), findsNothing);
    expect(find.byType(DesignScreen), findsOneWidget);
  });
}
