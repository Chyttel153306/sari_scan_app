import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/screens/checkout_screen.dart';
import 'package:sari_scan_app/src/screens/reports_screen.dart';
import 'package:sari_scan_app/src/screens/utang_screen.dart';
import 'package:sari_scan_app/src/store/app_store.dart';
import 'package:sari_scan_app/src/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    for (final family in ['PlusJakartaSans', 'SpaceGrotesk']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });

  testWidgets('utang filters show the correct pending and paid customers', (
    tester,
  ) async {
    final pending = Customer(
      id: '1',
      name: 'Maria',
      ledger: [
        LedgerEntry(
          id: '1',
          createdAt: DateTime.now(),
          type: LedgerEntryType.credit,
          amount: 50,
          note: 'Utang',
        ),
      ],
    );
    final paid = Customer(id: '2', name: 'Ana');
    final store = AppStore(customers: [pending, paid]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: UtangScreen(store: store)),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Paid'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Maria'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending'));
    await tester.pumpAndSettle();
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'modern screens remain usable at $width pixels with large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final product = Product(
          id: '1',
          name: 'Coffee original blend',
          category: 'Drinks',
          price: 25,
          costPrice: 15,
          stock: 10,
        );
        final rice = Product(
          id: '2',
          name: 'Rice',
          category: 'Pantry',
          price: 50,
          stock: 10,
        );
        final store = AppStore(products: [product, rice]);
        await store.openSecureSession('Maria Santos');
        store.addToCart(product);
        store.completeSale(paymentType: PaymentType.cash, amountReceived: 50);
        store.addToCart(product);
        await tester.pumpWidget(SariScanApp(store: store));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Add to cart').first);
        await tester.pumpAndSettle();
        expect(store.cartItemCount, 2);
        await tester.tap(find.text('Products').last);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Drinks'));
        await tester.pumpAndSettle();
        expect(find.text('Rice'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Utang').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Reports').last);
        await tester.pumpAndSettle();
        final reportsScroll = find
            .descendant(
              of: find.byType(ReportsScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        for (var i = 0; i < 4; i++) {
          await tester.drag(reportsScroll, const Offset(0, -250));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.text('POS').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Charge'));
        await tester.pumpAndSettle();
        expect(find.byType(CheckoutScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await Scrollable.ensureVisible(
          tester.element(find.text('Exact')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Exact'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Complete sale'));
        await tester.pumpAndSettle();
        expect(store.sales, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
