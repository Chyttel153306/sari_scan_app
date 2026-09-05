import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/screens/checkout_screen.dart';
import 'package:sari_scan_app/src/store/app_store.dart';

AppStore checkoutStore({bool withCustomer = false}) {
  final product = Product(
    id: '1',
    name: 'Rice',
    category: 'Food',
    price: 50,
    stock: 10,
  );
  return AppStore(
    products: [product],
    customers: [if (withCustomer) Customer(id: 'existing', name: 'Ana')],
  )..addToCart(product);
}

Future<void> addMaria(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(TextButton, 'Add customer'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Add customer'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Customer name'),
    ' Maria ',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Phone (optional)'),
    '09171234567',
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Add customer'));
  await tester.pumpAndSettle();
}

void main() {
  for (final withCustomer in [false, true]) {
    testWidgets(
      'creates and selects a checkout customer with existing list: $withCustomer',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = checkoutStore(withCustomer: withCustomer);
        await tester.pumpWidget(
          MaterialApp(home: CheckoutScreen(store: store)),
        );
        await tester.tap(find.text('Utang'));
        await tester.pumpAndSettle();
        await addMaria(tester);

        final customer = store.customers.last;
        expect(customer.name, 'Maria');
        expect(customer.phone, '09171234567');
        expect(
          tester
              .widget<DropdownButtonFormField<Customer>>(
                find.byType(DropdownButtonFormField<Customer>),
              )
              .initialValue,
          customer,
        );
        expect(store.cartItemCount, 1);
        expect(store.sales, isEmpty);
        expect(customer.balance, 0);

        await tester.ensureVisible(find.text('Complete sale'));
        await tester.tap(find.text('Complete sale'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(store.sales.single.paymentType, PaymentType.utang);
        expect(store.sales.single.customerId, customer.id);
        expect(customer.balance, 50);
        expect(customer.ledger, hasLength(1));
        expect(store.cartItemCount, 0);
      },
    );
  }

  testWidgets(
    'cancelling customer creation keeps the existing selection and cart',
    (tester) async {
      final store = checkoutStore(withCustomer: true);
      await tester.pumpWidget(MaterialApp(home: CheckoutScreen(store: store)));
      await tester.tap(find.text('Utang'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<Customer>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<Customer>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana • ₱0.00 balance').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Add customer'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Add customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(store.customers, hasLength(1));
      expect(
        tester
            .widget<DropdownButtonFormField<Customer>>(
              find.byType(DropdownButtonFormField<Customer>),
            )
            .initialValue,
        store.customers.single,
      );
      expect(store.cartItemCount, 1);
      expect(store.sales, isEmpty);
    },
  );

  testWidgets(
    'switching back to cash does not charge the created customer utang',
    (tester) async {
      final store = checkoutStore();
      await tester.pumpWidget(MaterialApp(home: CheckoutScreen(store: store)));
      await tester.tap(find.text('Utang'));
      await tester.pumpAndSettle();
      await addMaria(tester);
      await tester.ensureVisible(find.text('Cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Cash received'),
        '50',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Complete sale'));
      await tester.tap(find.text('Complete sale'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(store.sales.single.paymentType, PaymentType.cash);
      expect(store.sales.single.customerId, isNull);
      expect(store.customers.single.ledger, isEmpty);
    },
  );
}
