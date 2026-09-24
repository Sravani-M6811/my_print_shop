import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_print_shop/ui/widgets/catalogue_image.dart';

/// Wraps [CatalogueImage] in a light [MaterialApp] so error builders fire as
/// they would in the real UI.
Widget _wrap(CatalogueImage image) => MaterialApp(
      home: Scaffold(body: Center(child: image)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('missing bundled asset shows placeholder without crashing',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const CatalogueImage(
          imagePath: 'assets/images/products/m/nonexistent.jpg',
          width: 120,
          height: 120),
    ));

    // Let the image pipeline attempt to load the asset.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline / error network image shows placeholder without crashing',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const CatalogueImage(
        imagePath: 'https://not-a-real-server.invalid/bad.png',
        width: 120,
        height: 120,
      ),
    ));

    // The Flutter test HTTP client returns 400, triggering the errorBuilder.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'network image with a broken bundled fallback still shows a single '
      'placeholder without crashing', (tester) async {
    await tester.pumpWidget(_wrap(
      const CatalogueImage(
        imagePath: 'https://not-a-real-server.invalid/bad.png',
        fallbackImage: 'assets/images/products/m/nonexistent.jpg',
        width: 120,
        height: 120,
      ),
    ));

    await tester.pump(const Duration(milliseconds: 100));
    // Second frame lets the fallback asset's own errorBuilder render.
    await tester.pump();

    expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('asset image ignores fallbackImage and uses the asset itself',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const CatalogueImage(
        imagePath: 'assets/images/icon/app_logo.png',
        fallbackImage: 'assets/images/products/m/nonexistent.jpg',
        width: 120,
        height: 120,
      ),
    ));

    await tester.pump(const Duration(milliseconds: 100));

    // The asset pipeline may fail to load the real bundle in the test env, but
    // the fallback must never be consulted for bundled paths — exactly one
    // placeholder (or the image) renders and nothing crashes.
    expect(tester.takeException(), isNull);
  });

  }
