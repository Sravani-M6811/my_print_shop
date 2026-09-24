import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_print_shop/frontend/models/product.dart';
import 'package:my_print_shop/admin/screens/admin_products_screen.dart';

import 'helpers/fake_catalogue_repository.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeCatalogueRepository repo,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AdminProductsScreen(repository: repo))),
    );
    await tester.pumpAndSettle();
  }

  Product adminProduct(String id, String name) => Product(
        id: id,
        name: name,
        category: 'Mugs',
        description: 'Admin-managed product',
        basePrice: 299,
        imagePath: 'assets/images/products/mugs/plain_mug.jpg',
      );

  group('AdminProductsScreen list rendering', () {
    testWidgets('renders the static catalogue first record', (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      expect(find.text('Elegant Silk Saree'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows admin-managed override records when searched',
        (tester) async {
      final repo = FakeCatalogueRepository();
      repo.products.add(adminProduct('mug_admin_1', 'Admin Nova Mug'));
      await pumpScreen(tester, repo);

      await tester.enterText(find.byType(TextField), 'Admin Nova Mug');
      await tester.pump();

      expect(find.widgetWithText(Card, 'Admin Nova Mug'), findsOneWidget);
      expect(find.text('Elegant Silk Saree'), findsNothing);
    });

    testWidgets('search filters the list', (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      await tester.enterText(find.byType(TextField), 'Designer Georgette Saree');
      await tester.pump();

      expect(find.widgetWithText(Card, 'Designer Georgette Saree'), findsOneWidget);
      expect(find.text('Elegant Silk Saree'), findsNothing);
    });

    testWidgets('shows the empty state when no result matches the search',
        (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      await tester.enterText(find.byType(TextField), 'zzzz-no-such-product');
      await tester.pump();

      expect(find.text('No products found'), findsOneWidget);
    });

    testWidgets('shows an error state with a working Retry button',
        (tester) async {
      final repo = FakeCatalogueRepository()..failProductsFetch = true;
      await pumpScreen(tester, repo);

      expect(find.text('Could not load products.'), findsOneWidget);

      repo.failProductsFetch = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load products.'), findsNothing);
      expect(find.text('Elegant Silk Saree'), findsOneWidget);
    });

    testWidgets('renders a DataTable on wide layouts', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = FakeCatalogueRepository();
      repo.products.add(adminProduct('mug_admin_1', 'Admin Nova Mug'));

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AdminProductsScreen(repository: repo))),
      );
      await tester.enterText(find.byType(TextField), 'Admin Nova Mug');
      await tester.pumpAndSettle();

expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.textContaining('Nova'), findsWidgets);
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

  group('AdminProductsScreen create / update / delete', () {
    testWidgets('adds a product through the form', (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      await tester.tap(find.text('Add Product'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'Test Widget Product');
      await tester.enterText(find.byType(TextFormField).at(1), '349');
      await tester.enterText(find.byType(TextFormField).at(2),
          'assets/images/products/mugs/plain_mug.jpg');
      final saveButton = find.widgetWithText(ElevatedButton, 'Add Product');
      await tester.scrollUntilVisible(saveButton, 150,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repo.productCreatedIds, hasLength(1));
      expect(repo.products.single.name, 'Test Widget Product');
      expect(repo.products.single.basePrice, 349);
    });

    testWidgets('validates required fields on add', (tester) async {
      final repo = FakeCatalogueRepository();
      await pumpScreen(tester, repo);

      await tester.tap(find.text('Add Product'));
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(ElevatedButton, 'Add Product');
      await tester.scrollUntilVisible(saveButton, 150,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Product name is required'), findsOneWidget);
      expect(find.text('Price is required'), findsOneWidget);
      expect(find.text('Image is required'), findsOneWidget);
      expect(repo.productCreatedIds, isEmpty);
    });

    testWidgets('edits a static product and persists via the repository',
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

      expect(repo.productUpdatedIds, contains('saree_1'));
      final stored =
          repo.products.firstWhere((p) => p.id == 'saree_1');
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

      expect(find.text('Delete product?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repo.productDeactivatedIds, contains('saree_1'));
      final stored =
          repo.products.firstWhere((p) => p.id == 'saree_1');
      expect(stored.availability, isFalse);
    });

    testWidgets('cancelling the delete dialog keeps the product', (tester) async {
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

      expect(repo.productDeactivatedIds, isEmpty);
      expect(find.text('Elegant Silk Saree'), findsOneWidget);
    });
  });
}



