import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/services/local_storage_service.dart';
import 'package:sari_scan_app/src/store/app_store.dart';

void main() {
  group('AppStore sales', () {
    test('calculates cart totals, change, and stock updates', () {
      final product = Product(
        id: '1',
        name: 'Test Product',
        category: 'Test',
        price: 12.50,
        stock: 10,
      );
      final store = AppStore(products: [product]);

      store.addToCart(product);
      store.addToCart(product);

      expect(store.cartTotal, 25);
      final sale = store.completeSale(
        paymentType: PaymentType.cash,
        amountReceived: 30,
      );

      expect(sale.total, 25);
      expect(sale.change, 5);
      expect(product.stock, 8);
      expect(store.cartItemCount, 0);
      expect(store.sales, hasLength(1));
    });

    test('blocks an insufficient cash payment', () {
      final product = Product(
        id: '1',
        name: 'Test Product',
        category: 'Test',
        price: 20,
        stock: 2,
      );
      final store = AppStore(products: [product])..addToCart(product);

      expect(
        () => store.completeSale(
          paymentType: PaymentType.cash,
          amountReceived: 10,
        ),
        throwsStateError,
      );
      expect(product.stock, 2);
    });

    test('creates utang ledger entries and records repayments', () {
      final product = Product(
        id: '1',
        name: 'Rice',
        category: 'Food',
        price: 50,
        stock: 5,
      );
      final customer = Customer(id: '1', name: 'Maria');
      final store = AppStore(products: [product], customers: [customer])
        ..addToCart(product);

      store.completeSale(paymentType: PaymentType.utang, customer: customer);
      expect(customer.balance, 50);
      expect(customer.ledger.single.type, LedgerEntryType.credit);

      expect(store.recordPayment(customer, 20), isNull);
      expect(customer.balance, 30);
      expect(store.recordPayment(customer, 40), isNotNull);
      expect(customer.balance, 30);
    });
  });

  test('secure session requires the registered owner name', () async {
    final store = AppStore();
    expect(await store.openSecureSession(''), isNotNull);
    expect(await store.openSecureSession('Owner'), isNull);
    expect(store.isAuthenticated, isTrue);
    await store.logout();
    expect(store.validateOwnerName('Someone Else'), isNotNull);
    expect(await store.openSecureSession('owner'), isNull);
  });

  test('app state starts without demo products or customers', () {
    final store = AppStore.forApp();
    expect(store.products, isEmpty);
    expect(store.customers, isEmpty);
  });

  test('persists the account and all store records on the device', () async {
    final directory = await Directory.systemTemp.createTemp('sariscan_test_');
    final storage = LocalStorageService(File('${directory.path}/store.json'));

    try {
      final store = AppStore.forApp(storage: storage);
      await store.initialize();
      expect(await store.openSecureSession('Owner'), isNull);

      final product = store.saveProduct(
        name: 'Rice',
        category: 'Food',
        price: 50,
        stock: 10,
        barcode: '123',
        lowStockThreshold: 2,
      );
      final customer = store.addCustomer('Maria', '09171234567');
      store.addToCart(product);
      store.completeSale(paymentType: PaymentType.utang, customer: customer);
      expect(store.recordPayment(customer, 20), isNull);
      await store.persistenceSettled;

      final restored = AppStore.forApp(storage: storage);
      await restored.initialize();

      expect(restored.isAuthenticated, isFalse);
      expect(restored.validateOwnerName('Owner'), isNull);
      expect(await restored.openSecureSession('Owner'), isNull);
      expect(restored.products.single.name, 'Rice');
      expect(restored.products.single.stock, 9);
      expect(restored.customers.single.balance, 30);
      expect(restored.sales.single.items.single.productName, 'Rice');

      await restored.logout();
      final afterLogout = AppStore.forApp(storage: storage);
      await afterLogout.initialize();
      expect(afterLogout.isAuthenticated, isFalse);
      expect(afterLogout.products, hasLength(1));
      expect(afterLogout.sales, hasLength(1));

      // Deleting a product also clears its cart reference and keeps
      // historical receipt and debt snapshots after the next app launch.
      afterLogout.addToCart(afterLogout.products.single);
      final deleted = afterLogout.products.single;
      afterLogout.deleteProduct(deleted);
      expect(afterLogout.cartLines, isEmpty);
      expect(afterLogout.cartTotal, 0);
      afterLogout.addToCart(deleted);
      expect(afterLogout.cartLines, isEmpty);
      await afterLogout.persistenceSettled;
      final afterDelete = AppStore.forApp(storage: storage);
      await afterDelete.initialize();
      expect(afterDelete.products, isEmpty);
      expect(afterDelete.sales.single.total, 50);
      expect(afterDelete.sales.single.items.single.productName, 'Rice');
      expect(afterDelete.customers.single.balance, 30);
      expect(afterDelete.customers.single.ledger, hasLength(2));
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
