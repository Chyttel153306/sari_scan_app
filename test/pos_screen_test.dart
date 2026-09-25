import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/screens/pos_screen.dart';
import 'package:sari_scan_app/src/screens/products_screen.dart';
import 'package:sari_scan_app/src/screens/reports_screen.dart';
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
  testWidgets('cart updates do not rebuild the app catalog or hidden tabs', (
    tester,
  ) async {
    final product = Product(
      id: '1',
      name: 'Rice',
      category: 'Food',
      price: 50,
      stock: 10,
    );
    final store = _CountingStore(products: [product]);
    addTearDown(store.dispose);
    await store.openSecureSession('Owner');
    await tester.pumpWidget(SariScanApp(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(ProductsScreen, skipOffstage: false), findsNothing);
    expect(find.byType(ReportsScreen, skipOffstage: false), findsNothing);

    await tester.tap(find.text('Reports').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('POS').last);
    await tester.pumpAndSettle();
    final cardBefore = tester.widget(find.byType(CatalogProductCard));
    final reportBefore = tester.widget(
      find.byType(ReportsScreen, skipOffstage: false),
    );
    final readsBefore = store.catalogReads;
    await tester.tap(find.byType(CatalogProductCard));
    await tester.pumpAndSettle();
    expect(find.text('1 Items in Cart'), findsOneWidget);
    expect(store.catalogReads, readsBefore);
    expect(tester.widget(find.byType(CatalogProductCard)), same(cardBefore));
    expect(
      tester.widget(find.byType(ReportsScreen, skipOffstage: false)),
      same(reportBefore),
    );

    store.removeOneFromCart(product);
    await tester.pumpAndSettle();
    expect(find.text('1 Items in Cart'), findsNothing);
    expect(store.catalogReads, readsBefore);

    store.saveProduct(
      existing: product,
      name: 'Premium Rice',
      category: 'Food',
      price: 60,
      barcode: '',
      lowStockThreshold: 5,
    );
    await tester.pumpAndSettle();
    expect(find.text('Premium Rice'), findsOneWidget);
    await tester.tap(find.byType(CatalogProductCard));
    await tester.pumpAndSettle();
    expect(store.cartTotal, 60);
    store.toggleArchive(product);
    await tester.pumpAndSettle();
    expect(find.text('0 products available'), findsOneWidget);
    expect(find.text('1 Items in Cart'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
