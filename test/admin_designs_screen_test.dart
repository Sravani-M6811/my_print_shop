import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_print_shop/frontend/models/design.dart';
import 'package:my_print_shop/admin/screens/admin_designs_screen.dart';

import 'helpers/fake_catalogue_repository.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeCatalogueRepository repo,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AdminDesignsScreen(repository: repo))),
    );
    await tester.pumpAndSettle();
  }

  Design adminDesign(String id, String name) => Design(
        designId: id,
        name: name,
        category: 'Sarees',
        imagePath: 'assets/images/designs/sarees/admin_floral.jpg',
        tags: const ['admin'],
        designType: 'Abstract',
      );

  group('AdminDesignsScreen list rendering', () {
    testWidgets('renders the static design catalogue first record',
        (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      expect(find.text('Elegant Silk Saree'), findsOneWidget);
    });

    testWidgets('shows admin-managed override designs when searched',
        (tester) async {
      final repo = FakeCatalogueRepository();
      repo.designs.add(adminDesign('d_admin_1', 'Admin Floral Motif'));
      await pumpScreen(tester, repo);

      await tester.enterText(find.byType(TextField), 'Admin Floral Motif');
      await tester.pump();

      expect(find.widgetWithText(Card, 'Admin Floral Motif'), findsOneWidget);
      expect(find.text('Elegant Silk Saree'), findsNothing);
    });

    testWidgets('search filters the design list', (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      await tester.enterText(
          find.byType(TextField), 'Designer Georgette Saree');
      await tester.pump();

      expect(find.widgetWithText(Card, 'Designer Georgette Saree'), findsOneWidget);
      expect(find.text('Elegant Silk Saree'), findsNothing);
    });

    testWidgets('shows the empty state when no design matches the search',
        (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      await tester.enterText(find.byType(TextField), 'zzzz-no-such-design');
      await tester.pump();

      expect(find.text('No designs found'), findsOneWidget);
    });

    testWidgets('shows an error state with a working Retry button',
        (tester) async {
      final repo = FakeCatalogueRepository()..failDesignsFetch = true;
      await pumpScreen(tester, repo);

      expect(find.text('Could not load designs.'), findsOneWidget);

      repo.failDesignsFetch = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load designs.'), findsNothing);
      expect(find.text('Elegant Silk Saree'), findsOneWidget);
    });

    testWidgets('renders a DataTable on wide layouts', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = FakeCatalogueRepository();

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AdminDesignsScreen(repository: repo))),
      );
      await tester.enterText(find.byType(TextField), 'zari');
      await tester.pumpAndSettle();

expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.byType(TableCell), findsWidgets);
    });

    testWidgets('filters by category on narrow layouts', (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      await tester.tap(find.byType(DropdownButton<String>).first,
          warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saree Borders').last);
      await tester.pumpAndSettle();

      expect(find.text('Elegant Silk Saree'), findsNothing);
      expect(find.textContaining('Saree Borders'), findsWidgets);
      expect(find.byType(DataTable), findsNothing);
    });
  });

  group('AdminDesignsScreen create / update / delete', () {
    testWidgets('adds a design through the form', (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      await tester.tap(find.text('Add Design'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'Test Admin Design');
      await tester.enterText(find.byType(TextFormField).at(1),
          'assets/images/designs/sarees/test.jpg');
      final saveButton = find.widgetWithText(ElevatedButton, 'Add Design');
      await tester.scrollUntilVisible(saveButton, 150,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repo.designCreatedIds, hasLength(1));
      expect(repo.designs.single.name, 'Test Admin Design');
    });

    testWidgets('adds a design with compatibility assignment', (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      await tester.tap(find.text('Add Design'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'Wedding Border Motif');
      await tester.enterText(find.byType(TextFormField).at(1),
          'assets/images/designs/sarees/wedding_border.jpg');

      final compatHeader =
          find.text('Compatible Categories');
      await tester.scrollUntilVisible(compatHeader, 200,
          scrollable: find.byType(Scrollable).first);

      await tester.tap(find.widgetWithText(FilterChip, 'Mugs'));
      await tester.pump();

      await tester.enterText(
          find.byKey(const ValueKey('compatibleProductIds')),
          'base_saree, base_tshirt');

      final saveButton = find.widgetWithText(ElevatedButton, 'Add Design');
      await tester.scrollUntilVisible(saveButton, 150,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repo.designCreatedIds, hasLength(1));
      final stored = repo.designs.single;
      expect(stored.name, 'Wedding Border Motif');
      expect(stored.compatibleCategories, contains('Mugs'));
      expect(stored.compatibleProductIds, containsAll(['base_saree', 'base_tshirt']));
    });

    testWidgets('validates required fields on add', (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      await tester.tap(find.text('Add Design'));
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(ElevatedButton, 'Add Design');
      await tester.scrollUntilVisible(saveButton, 150,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Design name is required'), findsOneWidget);
      expect(find.text('Image is required'), findsOneWidget);
      expect(repo.designCreatedIds, isEmpty);
    });

    testWidgets('edits a static design and persists via the repository',
        (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      final card = find.widgetWithText(Card, 'Elegant Silk Saree');
      await tester.tap(find.descendant(
        of: card,
        matching: find.byIcon(Icons.edit_outlined),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'Elegant Silk Saree (Edited)');
      final saveButton = find.widgetWithText(ElevatedButton, 'Save Changes');
      await tester.scrollUntilVisible(saveButton, 150,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repo.designUpdatedIds, contains('saree_1'));
      final stored = repo.designs.firstWhere((d) => d.designId == 'saree_1');
      expect(stored.name, 'Elegant Silk Saree (Edited)');
    });

    testWidgets('delete asks for confirmation and soft-deactivates',
        (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      final card = find.widgetWithText(Card, 'Elegant Silk Saree');
      await tester.tap(find.descendant(
        of: card,
        matching: find.byIcon(Icons.delete_outline),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Delete design?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repo.designDeactivatedIds, contains('saree_1'));
      final stored = repo.designs.firstWhere((d) => d.designId == 'saree_1');
      expect(stored.availability, isFalse);
    });

    testWidgets('cancelling the delete dialog keeps the design', (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      final card = find.widgetWithText(Card, 'Elegant Silk Saree');
      await tester.tap(find.descendant(
        of: card,
        matching: find.byIcon(Icons.delete_outline),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.designDeactivatedIds, isEmpty);
      expect(find.text('Elegant Silk Saree'), findsOneWidget);
    });
  });
}



