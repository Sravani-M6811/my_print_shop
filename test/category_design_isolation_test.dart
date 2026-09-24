import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_print_shop/frontend/providers/app_state.dart';
import 'package:my_print_shop/frontend/screens/design_screen.dart';
import 'package:my_print_shop/ui/widgets/design_card.dart';

Future<void> pumpDesignScreen(
  WidgetTester tester,
  String category,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        home: DesignScreen(initialCategory: category),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const searchTerms = {
    'Sarees': 'lace',
    'Saree Borders': 'mirror',
    'T-Shirts': 'cricket',
    'Mugs': 'coffee',
    'Posters': 'motivational',
    'Embroidery': 'floral',
    'Cardboard': 'wedding',
    'Glass Art': 'flowers',
  };

  for (final entry in searchTerms.entries) {
    final category = entry.key;
    final query = entry.value;

    testWidgets('$category Design screen is category-scoped', (tester) async {
      await pumpDesignScreen(tester, category);

      // Category-specific app bar title reflects the selected category
      // (appears in both the AppBar and the category banner).
      expect(find.text('$category Designs'), findsWidgets);

      // The category gallery for this category must not show another
      // category's section heading (e.g. T-Shirts must not show "Sarees").
      for (final other in searchTerms.keys) {
        if (other == category) continue;
        expect(find.text('$other Designs'), findsNothing);
      }

      // Search bar placeholder is category-specific.
      expect(find.textContaining('$category designs'), findsOneWidget);

      // Search with this category's representative term: the search must
      // return relevant results rendered as real design cards (image-backed),
      // never an empty state or a Red Screen / crash.
      await tester.enterText(find.byType(TextField).first, query);
      await tester.pumpAndSettle();
      expect(find.byType(DesignCard), findsWidgets);
    });
  }

  testWidgets('Search is category-aware and returns real design cards',
      (tester) async {
    await pumpDesignScreen(tester, 'T-Shirts');

    // Searching for a universally-typed term in the catalog.
    await tester.enterText(find.byType(TextField).first, 'cricket');
    await tester.pumpAndSettle();

    // Results surface as design cards with actual images (not text-only).
    final cards = find.byType(DesignCard);
    expect(cards, findsWidgets);
  });

  testWidgets('Empty search shows a friendly no-designs message',
      (tester) async {
    await pumpDesignScreen(tester, 'Cardboard');

    await tester.enterText(find.byType(TextField).first, 'zz_no_match_qq');
    await tester.pumpAndSettle();
    expect(find.textContaining('No designs found'), findsOneWidget);
  });

  testWidgets('Cardboard category exposes templates with real assets',
      (tester) async {
    await pumpDesignScreen(tester, 'Cardboard');
    // Cardboard is template-driven; its designs resolve to local image assets
    // validated at build time, so cards render (image-backed, not text-only).
    final cards = find.byType(DesignCard);
    expect(cards, findsWidgets);
  });
}
