import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/services/local_storage_service.dart';
import 'package:sari_scan_app/src/store/app_store.dart';

Product save(
  AppStore store,
  String barcode, {
  Product? existing,
  double price = 10,
  double? cost = 5,
  int stock = 3,
  int threshold = 1,
  String name = 'Milk',
  String category = 'Food',
}) => store.saveProduct(
  existing: existing,
  name: name,
  category: category,
  price: price,
  costPrice: cost,
  stock: stock,
  barcode: barcode,
  lowStockThreshold: threshold,
);

void main() {
  test(
    'UPC and EAN lookup works in both directions, including old catalog whitespace',
    () {
      for (final savedCode in ['012345678905', '0012345678905']) {
        final store = AppStore();
        addTearDown(store.dispose);
        final product = save(store, savedCode);
        product.barcode = ' $savedCode ';
        expect(store.findByBarcode('012345678905'), same(product));
        expect(store.findByBarcode(' 0012345678905\r\n'), same(product));
        expect(store.findByBarcode('0012345678906'), isNull);
      }
    },
  );

  test(
    'blank codes do not match and custom codes retain zeros and letter case',
    () {
      final store = AppStore();
      addTearDown(store.dispose);
      save(store, '');
      final product = save(store, ' 00123-A ');
      final numeric = save(store, '00123');
      expect(store.findByBarcode(' \n'), isNull);
      expect(store.findByBarcode('00123-A'), same(product));
      expect(store.findByBarcode('123-A'), isNull);
      expect(store.findByBarcode('00123-a'), isNull);
      expect(store.findByBarcode('00123'), same(numeric));
      expect(store.findByBarcode('123'), isNull);
    },
  );

  test('duplicate equivalents are blocked on create, edit and restore', () {
    final store = AppStore();
    addTearDown(store.dispose);
    final original = save(store, '012345678905');
    expect(() => save(store, '0012345678905'), throwsArgumentError);
    final other = save(store, 'CUSTOM');
    expect(
      () => save(store, '0012345678905', existing: other),
      throwsArgumentError,
    );
    expect(other.barcode, 'CUSTOM');
    save(store, '0012345678905', existing: original);
    store.toggleArchive(original);
    expect(store.findByBarcode('012345678905'), isNull);
    final replacement = save(store, '012345678905');
    expect(store.toggleArchive(original), isNotNull);
    expect(original.isArchived, isTrue);
    expect(store.findByBarcode('0012345678905'), same(replacement));
    save(store, 'NEW', existing: original);
    expect(store.toggleArchive(original), isNull);
  });

  test('barcodes survive device storage and reload', () async {
    final directory = await Directory.systemTemp.createTemp('barcode_store_');
    addTearDown(() => directory.delete(recursive: true));
    final storage = LocalStorageService(File('${directory.path}/store.json'));
    final store = AppStore.forApp(storage: storage);
    addTearDown(store.dispose);
    await store.initialize();
    save(store, '012345678905');
    await store.persistenceSettled;
    final restored = AppStore.forApp(storage: storage);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.findByBarcode('0012345678905')?.barcode, '012345678905');
  });

  test('invalid product inputs cannot mutate inventory', () {
    final store = AppStore();
    addTearDown(store.dispose);
    for (final invalid in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
      -1.0,
    ]) {
      expect(() => save(store, '', price: invalid), throwsArgumentError);
      expect(() => save(store, '', cost: invalid), throwsArgumentError);
    }
    expect(() => save(store, '', stock: -1), throwsArgumentError);
    expect(() => save(store, '', threshold: -1), throwsArgumentError);
    expect(() => save(store, '', name: ' '), throwsArgumentError);
    expect(() => save(store, '', category: ' '), throwsArgumentError);
    expect(store.products, isEmpty);
    expect(store.stockAdditions, isEmpty);
    final product = save(store, '');
    store.deleteProduct(product);
    expect(() => save(store, 'NEW', existing: product), throwsArgumentError);
  });

  test('invalid cash and debt payments preserve stock and balances', () {
    final store = AppStore();
    addTearDown(store.dispose);
    final product = save(store, '');
    final customer = store.addCustomer('Customer', '');
    store.addToCart(product);
    for (final invalid in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(
        () => store.completeSale(
          paymentType: PaymentType.cash,
          amountReceived: invalid,
        ),
        throwsStateError,
      );
      expect(store.recordPayment(customer, invalid), isNotNull);
    }
    expect(product.stock, 3);
    expect(store.sales, isEmpty);
    expect(customer.ledger, isEmpty);
    store.completeSale(
      paymentType: PaymentType.cash,
      amountReceived: 10,
      customer: customer,
    );
    expect(customer.ledger, isEmpty);
  });
}
