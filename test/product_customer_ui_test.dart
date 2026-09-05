import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/screens/pos_screen.dart';
import 'package:sari_scan_app/src/screens/products_screen.dart';
import 'package:sari_scan_app/src/screens/utang_screen.dart';
import 'package:sari_scan_app/src/store/app_store.dart';
import 'package:sari_scan_app/src/widgets/price_text.dart';

void main() {
  testWidgets('recording an utang payment closes its fields safely', (
    tester,
  ) async {
    final customer = Customer(
      id: '1',
      name: 'Maria',
      ledger: [
        LedgerEntry(
          id: '1',
          createdAt: DateTime.now(),
          type: LedgerEntryType.credit,
          amount: 50,
          note: 'Utang sale',
        ),
      ],
    );
    final store = AppStore(customers: [customer]);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerLedgerScreen(store: store, customer: customer),
      ),
    );
    await tester.tap(find.text('Pay Utang'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '20');
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(customer.balance, 30);
    expect(find.text('Customer payment'), findsOneWidget);
  });

  testWidgets('adding a customer closes safely and opens their ledger', (
    tester,
  ) async {
    final store = AppStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UtangScreen(store: store)),
      ),
    );
    await tester.tap(find.text('Add customer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), ' Maria ');
    await tester.enterText(find.byType(TextField).at(2), '09171234567');
    await tester.tap(find.widgetWithText(FilledButton, 'Add customer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.customers.single.name, 'Maria');
    expect(find.text('No credit purchases or payments yet.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Maria'), findsOneWidget);
  });

  testWidgets('customer name is required and cancellation is safe', (
    tester,
  ) async {
    final store = AppStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UtangScreen(store: store)),
      ),
    );
    await tester.tap(find.text('Add customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add customer'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a customer name.'), findsOneWidget);
    expect(store.customers, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.customers, isEmpty);
  });

  testWidgets('product deletion requires confirmation and removes cart items', (
    tester,
  ) async {
    final product = Product(
      id: '1',
      name: 'Rice',
      category: 'Food',
      price: 50,
      stock: 10,
    );
    final store = AppStore(products: [product])..addToCart(product);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductsScreen(store: store)),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.products, hasLength(1));
    expect(store.cartItemCount, 1);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete product'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete product'));
    await tester.pumpAndSettle();
    expect(store.products, isEmpty);
    expect(store.cartLines, isEmpty);
    expect(find.text('No products found.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    for (final inventory in [true, false]) {
      for (final textScale in [1.0, 1.5]) {
        testWidgets(
          '${inventory ? 'inventory' : 'POS'} prices fit at $width pixels and $textScale text scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final store = AppStore(
              products: [
                Product(
                  id: '1',
                  name: 'A long product name that needs two lines',
                  category: 'Food',
                  price: 1234567.89,
                  stock: 10,
                ),
                Product(
                  id: '2',
                  name: 'Short name',
                  category: 'Food',
                  price: 12.50,
                  stock: 10,
                ),
              ],
            );
            // Use the actual application theme, including its card/button sizes.
            await store.openSecureSession('Owner');
            tester.platformDispatcher.textScaleFactorTestValue = textScale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await tester.pumpWidget(SariScanApp(store: store));
            if (inventory) {
              await tester.tap(find.text('Products').last);
              await tester.pumpAndSettle();
              expect(find.byType(ProductsScreen), findsOneWidget);
            } else {
              expect(find.byType(PosScreen), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            final price = find.text('₱1,234,567.89').first;
            final shortPrice = find.text('₱12.50').first;
            expect(tester.widget<Text>(price).style?.fontSize, 22);
            expect(tester.widget<Text>(shortPrice).style?.fontSize, 22);
            expect(
              tester.getSize(price).height,
              tester.getSize(shortPrice).height,
            );
            final priceViewport = find
                .ancestor(of: price, matching: find.byType(PriceText))
                .first;
            final card = find
                .ancestor(of: price, matching: find.byType(Card))
                .first;
            expect(
              tester
                  .getRect(card)
                  .contains(tester.getRect(priceViewport).bottomRight),
              isTrue,
            );
            final shortCard = find
                .ancestor(of: shortPrice, matching: find.byType(Card))
                .first;
            expect(tester.getSize(card), tester.getSize(shortCard));
          },
        );
      }
    }
  }
}
