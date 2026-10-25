import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/models/sales_trend.dart';
import 'package:sari_scan_app/src/screens/login_screen.dart';
import 'package:sari_scan_app/src/screens/checkout_screen.dart';
import 'package:sari_scan_app/src/screens/receipt_screen.dart';
import 'package:sari_scan_app/src/services/local_storage_service.dart';
import 'package:sari_scan_app/src/screens/products_screen.dart';
import 'package:sari_scan_app/src/screens/utang_screen.dart';
import 'package:sari_scan_app/src/services/phone_security_service.dart';
import 'package:sari_scan_app/src/store/app_store.dart';
import 'package:sari_scan_app/src/widgets/sales_trend_chart.dart';

class PendingSecurity implements PhoneSecurityAuthenticator {
  final result = Completer<PhoneSecurityResult>();
  int calls = 0;
  @override
  Future<PhoneSecurityResult> authenticate() {
    calls++;
    return result.future;
  }
}

class FullDisk extends LocalStorageService {
  FullDisk() : super(File('unused.json'));
  @override
  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async =>
      throw const FileSystemException('Disk full');
}

void main() {
  for (final width in [900.0, 1200.0]) {
    testWidgets('main screens fit a large display at $width pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final p = Product(
        id: '1',
        name: 'Large display product',
        category: 'Food',
        price: 12.5,
        stock: 20,
        costPrice: 10,
      );
      final store = AppStore(
        products: [p],
        customers: [Customer(id: '1', name: 'Ana')],
      );
      addTearDown(store.dispose);
      await store.openSecureSession('QA Store');
      await store.dismissTutorial();
      store.addToCart(p);
      store.completeSale(paymentType: PaymentType.cash, amountReceived: 20);
      await tester.pumpWidget(SariScanApp(store: store));
      for (final index in [1, 2, 3, 0]) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byType(NavigationDestination).at(4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'failed sale save stays at checkout and restores stock and cart',
    (tester) async {
      final p = Product(
        id: '1',
        name: 'Rice',
        category: 'Food',
        price: 10,
        stock: 5,
      );
      final store = AppStore(products: [p], storage: FullDisk())..addToCart(p);
      addTearDown(store.dispose);
      await tester.pumpWidget(MaterialApp(home: CheckoutScreen(store: store)));
      await tester.enterText(find.byType(TextField), '20');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete sale'));
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptScreen), findsNothing);
      expect(find.byType(CheckoutScreen), findsOneWidget);
      expect(store.sales, isEmpty);
      expect(p.stock, 5);
      expect(store.cartItemCount, 1);
      expect(find.textContaining('Disk full'), findsOneWidget);
    },
  );

  testWidgets(
    'failed repayment save remains editable and restores the balance',
    (tester) async {
      final customer = Customer(
        id: '1',
        name: 'Ana',
        ledger: [
          LedgerEntry(
            id: '1',
            createdAt: DateTime(2026),
            type: LedgerEntryType.credit,
            amount: 100,
            note: 'Debt',
          ),
        ],
      );
      final store = AppStore(customers: [customer], storage: FullDisk());
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerLedgerScreen(store: store, customer: customer),
        ),
      );
      await tester.tap(find.text('Pay Utang'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '30');
      await tester.tap(find.text('Save payment'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(customer.balance, 100);
      expect(find.textContaining('Disk full'), findsOneWidget);
    },
  );
  testWidgets('stock delivery cannot be submitted twice during dismissal', (
    tester,
  ) async {
    final p = Product(
      id: '1',
      name: 'Rice',
      category: 'Food',
      price: 10,
      stock: 5,
    );
    final store = AppStore(products: [p]);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AddStockDialog(store: store, product: p),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '3');
    await tester.enterText(find.byType(TextFormField).last, 'Delivery');
    final submit = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add stock'))
        .onPressed!;
    submit();
    submit();
    await tester.pumpAndSettle();
    expect(p.stock, 8);
    expect(store.stockAdditions, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing report period clears the selected chart bucket', (
    tester,
  ) async {
    List<SalesTrendPoint> points(int count) => List.generate(
      count,
      (i) => SalesTrendPoint(
        label: 'Period $i',
        start: DateTime(2026, 1, i + 1),
        end: DateTime(2026, 1, i + 2),
        value: 10,
      ),
    );
    Widget chart(int count) => MaterialApp(
      home: Scaffold(body: SalesTrendChart(points: points(count))),
    );
    await tester.pumpWidget(chart(12));
    final lastBar = find.byType(InkWell).last;
    await tester.ensureVisible(lastBar);
    await tester.tap(lastBar);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(chart(4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('repayment cannot be submitted twice during dialog dismissal', (
    tester,
  ) async {
    final customer = Customer(
      id: '1',
      name: 'Ana',
      ledger: [
        LedgerEntry(
          id: '1',
          createdAt: DateTime(2026),
          type: LedgerEntryType.credit,
          amount: 100,
          note: 'Debt',
        ),
      ],
    );
    final store = AppStore(customers: [customer]);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerLedgerScreen(store: store, customer: customer),
      ),
    );
    await tester.tap(find.text('Pay Utang'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '30');
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save payment'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(customer.balance, 70);
    expect(
      customer.ledger.where((e) => e.type == LedgerEntryType.payment),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sign in ignores duplicate callbacks while authentication is pending',
    (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      final auth = PendingSecurity();
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(store: store, phoneSecurity: auth),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'Owner');
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue with Phone Security'),
      );
      button.onPressed!();
      button.onPressed!();
      expect(auth.calls, 1);
      auth.result.complete(const PhoneSecurityResult.failure('Cancelled'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
