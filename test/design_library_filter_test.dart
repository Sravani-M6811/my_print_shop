import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_print_shop/frontend/data/product_catalog.dart';
import 'package:my_print_shop/frontend/screens/design_screen.dart';

/// The design library's theme filter: data-driven chips (Floral, Mandala, ...)
/// that narrow the reusable design collection, plus graceful empty states.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder chipRow() => find.byKey(const ValueKey('design-theme-filters'));

  Finder chipIn(String label) => find.descendant(
        of: chipRow(),
        matching: find.text(label),
      );

  String themeWithResults(String category) {
    return ProductCatalog.designThemes.firstWhere(
      (t) => ProductCatalog.filterDesigns(category: category, theme: t)
          .isNotEmpty,
      orElse: () => ProductCatalog.designThemes.first,
    );
  }

  String themeWithoutResults(String category) {
    return ProductCatalog.designThemes.firstWhere(
      (t) => ProductCatalog.filterDesigns(category: category, theme: t)
          .isEmpty,
    );
  }

  test('filterDesigns narrows by theme AND category correctly', () {
    final theme = themeWithResults('Sarees');
    final results =
        ProductCatalog.filterDesigns(category: 'Sarees', theme: theme);

    expect(results, isNotEmpty,
        reason: '$theme must have Sarees designs to filter by');
    for (final d in results) {
      expect(d.category, 'Sarees');
      expect(ProductCatalog.themesForDesign(d), contains(theme),
          reason: '${d.designId} should be tagged $theme');
    }

    // A theme with no matches in a category yields an empty library (backed by
    // the widget empty state).
    final dryTheme = themeWithoutResults('T-Shirts');
    expect(ProductCatalog.filterDesigns(category: 'T-Shirts', theme: dryTheme),
        isEmpty);
  });

  testWidgets('theme chip narrows the Sarees gallery without breaking layout',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: DesignScreen(initialCategory: 'Sarees'),
    ));
    await tester.pumpAndSettle();

    // Chips exist above the gallery.
    expect(find.text('Browse by Theme'), findsOneWidget);
    expect(chipRow(), findsOneWidget);

    final theme = themeWithResults('Sarees');
    final themeChip = chipIn(theme);
    await tester.dragUntilVisible(themeChip, chipRow(), const Offset(-120, 0),
        maxIteration: 40);
    await tester.pumpAndSettle();
    await tester.tap(themeChip);
    await tester.pumpAndSettle();

    // The gallery still renders matching designs (non-empty theme).
    expect(
      find.descendant(
        of: find.byType(DesignScreen),
        matching: find.byWidgetPredicate(
            (w) => w is ChoiceChip && w.selected == true),
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull,
        reason: 'theme filtering must not overflow or throw');

    // Reset back to every theme.
    await tester.dragUntilVisible(chipIn('All'), chipRow(),
        const Offset(120, 0),
        maxIteration: 40);
    await tester.pumpAndSettle();
    await tester.tap(chipIn('All'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme with no matching designs shows an empty state',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: DesignScreen(initialCategory: 'T-Shirts'),
    ));
    await tester.pumpAndSettle();

    final theme = themeWithoutResults('T-Shirts');
    final themeChip = chipIn(theme);
    await tester.dragUntilVisible(themeChip, chipRow(), const Offset(-120, 0),
        maxIteration: 40);
    await tester.pumpAndSettle();
    await tester.tap(themeChip);
    await tester.pumpAndSettle();

    expect(find.textContaining('No "$theme" themed designs for T-Shirts'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
