import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/screens/pos_screen.dart';
import 'package:sari_scan_app/src/store/app_store.dart';
import 'package:sari_scan_app/src/widgets/catalog_product_card.dart';

class _CountingStore extends AppStore {
  _CountingStore({required super.products});

  int catalogReads = 0;

  @override
  List<Product> get activeProducts {
    catalogReads++;
    return super.activeProducts;
  }
}

void main() {
  testWidgets('large POS catalog scrolls without rescanning products', (
    tester,
  ) async {
    final store = _CountingStore(
      products: List.generate(
        1000,
        (index) => Product(
          id: '$index',
          name: 'Product $index',
          category: 'Food',
          price: 10,
          stock: 5,
        ),
      ),
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PosScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1000 products available'), findsOneWidget);
    expect(find.byType(CatalogProductCard).evaluate().length, lessThan(100));

    final readsBeforeScroll = store.catalogReads;
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -1500),
      2000,
    );
    await tester.pumpAndSettle();
    expect(store.catalogReads, readsBeforeScroll);
    expect(tester.takeException(), isNull);
  });

  testWidgets('POS cards add available products after filtering', (
    tester,
  ) async {
    final store = AppStore(
      products: [
        Product(id: '1', name: 'Rice', category: 'Food', price: 50, stock: 10),
        Product(id: '2', name: 'Milk', category: 'Drinks', price: 20, stock: 0),
      ],
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PosScreen(store: store)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Rice');
    await tester.pumpAndSettle();
    expect(find.text('1 products available'), findsOneWidget);
    await tester.tap(find.widgetWithText(CatalogProductCard, 'Rice'));
    await tester.pumpAndSettle();
    expect(store.cartItemCount, 1);
    expect(store.cartTotal, 50);

    await tester.enterText(find.byType(TextField), 'Milk');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CatalogProductCard, 'Milk'));
    await tester.pumpAndSettle();
    expect(store.cartItemCount, 1);
    expect(tester.takeException(), isNull);
  });
}
