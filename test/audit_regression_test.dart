import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/services/local_storage_service.dart';
import 'package:sari_scan_app/src/services/supabase_image_service.dart';
import 'package:sari_scan_app/src/services/supabase_sync_service.dart';
import 'package:sari_scan_app/src/store/app_store.dart';
import 'package:sari_scan_app/src/l10n/app_language.dart';

class MemoryStorage extends LocalStorageService {
  MemoryStorage() : super(File('unused.json'));
  Map<String, dynamic>? data;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<Map<String, dynamic>?> loadSnapshot() async => data;
  @override
  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    if (gate != null) await gate!.future;
    if (fail) throw const FileSystemException('Disk full');
    data = snapshot;
  }
}

class AuditCloud extends Fake implements SupabaseSyncService {
  Map<String, dynamic> data = emptySnapshot();
  Completer<void>? gate;
  int downloads = 0;
  @override
  Future<CloudSnapshot?> downloadSnapshot(
    String code, {
    bool join = false,
  }) async {
    downloads++;
    if (gate != null) await gate!.future;
    return CloudSnapshot(data: data, updatedAt: DateTime(2026));
  }
}

class AuditImages extends Fake implements SupabaseImageService {
  final deleted = <String>[];
  @override
  Future<String> uploadImage(String path, {required String syncCode}) async =>
      '$syncCode/new.jpg';
  @override
  Future<void> deleteImage(String path) async => deleted.add(path);
  @override
  void dispose() {}
}

Map<String, dynamic> emptySnapshot() => {
  'version': 3,
  'products': <dynamic>[],
  'customers': <dynamic>[],
  'sales': <dynamic>[],
  'stock_additions': <dynamic>[],
  'markup_percent': 10,
};
Product product(String id, double price) => Product(
  id: id,
  name: 'Product $id',
  category: 'Food',
  price: price,
  stock: 5,
);

void main() {
  test('failed durable utang sale restores the customer ledger', () async {
    final storage = MemoryStorage()..fail = true;
    final p = product('1', 10);
    final customer = Customer(id: '1', name: 'Ana');
    final store = AppStore(
      storage: storage,
      products: [p],
      customers: [customer],
    )..addToCart(p);
    addTearDown(store.dispose);
    await expectLater(
      store.completeSaleAndSave(
        paymentType: PaymentType.utang,
        customer: customer,
      ),
      throwsStateError,
    );
    expect(store.sales, isEmpty);
    expect(customer.ledger, isEmpty);
    expect(p.stock, 5);
    expect(store.cartItemCount, 1);
  });
  test('successful owner rename updates the active store identity', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    await store.openSecureSession('Old Store');
    expect(await store.renameOwner('New Store'), isNull);
    expect(store.registeredOwnerName, 'New Store');
    expect(store.currentUserName, 'New Store');
  });

  test('stock addition rejects integer overflow without an audit entry', () {
    final p = product('1', 10)..stock = 0x7fffffffffffffff;
    final store = AppStore(products: [p]);
    addTearDown(store.dispose);
    expect(
      () => store.addStock(product: p, quantity: 1, note: 'Delivery'),
      throwsArgumentError,
    );
    expect(p.stock, 0x7fffffffffffffff);
    expect(store.stockAdditions, isEmpty);
  });
  test('failed unlink restores records, pairing and cart', () async {
    final storage = MemoryStorage()..fail = true;
    final p = product('1', 10);
    final store = AppStore(products: [p], storage: storage)
      ..syncCode = 'STORE123';
    addTearDown(store.dispose);
    store.addToCart(p);
    expect(await store.leaveCloudSync(), contains('Disk full'));
    expect(store.products.single, same(p));
    expect(store.cartItemCount, 1);
    expect(store.syncCode, 'STORE123');
  });

  test('overlapping downloads are rejected before a second request', () async {
    final cloud = AuditCloud()..gate = Completer<void>();
    final store = AppStore(cloudSync: cloud)..syncCode = 'STORE123';
    addTearDown(store.dispose);
    final first = store.pullFromCloud();
    await Future<void>.delayed(Duration.zero);
    expect((await store.pullFromCloud()).isSuccess, isFalse);
    expect(cloud.downloads, 1);
    cloud.gate!.complete();
    expect((await first).isSuccess, isTrue);
  });

  test('payment rejects a customer detached by a store replacement', () {
    final stale = Customer(
      id: '1',
      name: 'Old customer',
      ledger: [
        LedgerEntry(
          id: '1',
          createdAt: DateTime(2026),
          type: LedgerEntryType.credit,
          amount: 50,
          note: '',
        ),
      ],
    );
    final store = AppStore();
    addTearDown(store.dispose);
    expect(store.recordPayment(stale, 10), isNotNull);
    expect(stale.balance, 50);
  });

  test('exact decimal cash payment is accepted and change is rounded', () {
    final store = AppStore(products: [product('1', .1), product('2', .2)]);
    addTearDown(store.dispose);
    for (final p in store.products) {
      store.addToCart(p);
    }
    expect(store.cartTotal, .3);
    final sale = store.completeSale(
      paymentType: PaymentType.cash,
      amountReceived: .3,
    );
    expect(sale.total, .3);
    expect(sale.change, 0);
  });

  test('decimal repayments settle the balance exactly', () {
    final customer = Customer(
      id: '1',
      name: 'Ana',
      ledger: [
        LedgerEntry(
          id: '1',
          createdAt: DateTime(2026),
          type: LedgerEntryType.credit,
          amount: .3,
          note: '',
        ),
      ],
    );
    final store = AppStore(customers: [customer]);
    addTearDown(store.dispose);
    expect(store.recordPayment(customer, .1), isNull);
    expect(store.recordPayment(customer, .2), isNull);
    expect(customer.balance, 0);
  });

  test('sale rejects stale customer and changed stock without mutation', () {
    final p = product('1', 10);
    final store = AppStore(products: [p]);
    addTearDown(store.dispose);
    store.addToCart(p);
    final outsider = Customer(id: 'outside', name: 'Old customer');
    expect(
      () => store.completeSale(
        paymentType: PaymentType.utang,
        customer: outsider,
      ),
      throwsStateError,
    );
    p.stock = 0;
    expect(
      () =>
          store.completeSale(paymentType: PaymentType.cash, amountReceived: 10),
      throwsStateError,
    );
    expect(store.sales, isEmpty);
    expect(outsider.ledger, isEmpty);
    expect(p.stock, 0);
  });

  for (final kind in [
    'bad row',
    'missing arrays',
    'future version',
    'duplicate IDs',
    'negative price',
  ]) {
    test('malformed cloud snapshot is rejected atomically: $kind', () async {
      final cloud = AuditCloud();
      final local = product('local', 10);
      final store = AppStore(products: [local], cloudSync: cloud)
        ..syncCode = 'STORE123';
      addTearDown(store.dispose);
      store.addToCart(local);
      cloud.data = emptySnapshot();
      switch (kind) {
        case 'bad row':
          cloud.data['sales'] = [
            {'id': 'bad'},
          ];
        case 'missing arrays':
          cloud.data = {'version': 3};
        case 'future version':
          cloud.data['version'] = 999;
        case 'duplicate IDs':
          cloud.data['customers'] = [
            {'id': '1', 'name': 'A', 'ledger': []},
            {'id': '1', 'name': 'B', 'ledger': []},
          ];
        case 'negative price':
          cloud.data['products'] = [
            {
              'id': '1',
              'name': 'Bad',
              'category': 'Food',
              'price': -1,
              'stock': 1,
            },
          ];
      }
      final result = await store.pullFromCloud();
      expect(result.isSuccess, isFalse);
      expect(store.products.single, same(local));
      expect(store.cartItemCount, 1);
      expect(store.syncCode, 'STORE123');
    });
  }

  test(
    'failed cloud persistence reports failure and restores local records',
    () async {
      final storage = MemoryStorage()..fail = true;
      final p = product('local', 10);
      final store = AppStore(
        products: [p],
        storage: storage,
        cloudSync: AuditCloud(),
      )..syncCode = 'STORE123';
      addTearDown(store.dispose);
      final result = await store.pullFromCloud();
      expect(result.isSuccess, isFalse);
      expect(store.products.single, same(p));
      expect(store.lastSyncedAt, isNull);
    },
  );

  test(
    'failed account saves do not authenticate or change registered name',
    () async {
      final storage = MemoryStorage()..fail = true;
      final store = AppStore(storage: storage);
      addTearDown(store.dispose);
      expect(await store.openSecureSession('Owner'), isNotNull);
      expect(store.isAuthenticated, isFalse);
      expect(store.hasLocalAccount, isFalse);
      storage.fail = false;
      expect(await store.openSecureSession('Owner'), isNull);
      storage.fail = true;
      expect(await store.renameOwner('Wrong name'), isNotNull);
      expect(store.registeredOwnerName, 'Owner');
    },
  );

  test('queued persistence completes safely after store disposal', () async {
    final storage = MemoryStorage()..gate = Completer<void>();
    final store = AppStore(storage: storage);
    store.addCustomer('Ana', '');
    final settled = store.persistenceSettled;
    store.dispose();
    storage.gate!.complete();
    await expectLater(settled, completes);
    expect(storage.data!['customers'], hasLength(1));
  });

  test(
    'preparing a replacement photo keeps the previous local and cloud image',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'sariscan_audit_photo_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final old = File('${dir.path}/old.jpg')..writeAsBytesSync([1, 2]);
      final fresh = File('${dir.path}/new.jpg')..writeAsBytesSync([3, 4]);
      final images = AuditImages();
      final store = AppStore(
        storage: LocalStorageService(File('${dir.path}/store.json')),
        imageSync: images,
      )..syncCode = 'STORE123';
      addTearDown(store.dispose);
      await store.importProductImage(
        fresh.path,
        previousPath: old.path,
        previousUrl: 'STORE123/old.jpg',
      );
      expect(await old.exists(), isTrue);
      expect(images.deleted, isEmpty);
      await store.importProductImage(
        null,
        previousPath: old.path,
        previousUrl: 'STORE123/old.jpg',
      );
      expect(await old.exists(), isTrue);
      expect(images.deleted, isEmpty);
    },
  );

  test('corrupt primary JSON falls back to the recoverable backup', () async {
    final dir = await Directory.systemTemp.createTemp('sariscan_audit_backup_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/store.json')..writeAsStringSync('{broken');
    File('${file.path}.bak').writeAsStringSync(
      '{"version":3,"products":[],"customers":[],"sales":[]}',
    );
    expect((await LocalStorageService(file).loadSnapshot())!['version'], 3);
  });

  test(
    'failed local loading cannot overwrite the unreadable snapshot',
    () async {
      final storage = MemoryStorage()..data = {'version': 999};
      final store = AppStore(storage: storage);
      addTearDown(store.dispose);
      await store.initialize();
      expect(store.storageError, isNotNull);
      expect(await store.updateLanguage(AppLanguage.bisaya), isNotNull);
      expect(storage.data, {'version': 999});
    },
  );

  test(
    'photo cleanup cannot delete a file outside the managed image cache',
    () async {
      final dir = await Directory.systemTemp.createTemp('sariscan_audit_path_');
      addTearDown(() => dir.delete(recursive: true));
      final victim = File('${dir.path}/store.json')
        ..writeAsStringSync('valuable data');
      await LocalStorageService(victim).deleteProductImage(victim.path);
      expect(await victim.exists(), isTrue);
    },
  );

  test('a pending download does not overwrite a local edit', () async {
    final cloud = AuditCloud()..gate = Completer<void>();
    final store = AppStore(cloudSync: cloud)..syncCode = 'STORE123';
    addTearDown(store.dispose);
    final pending = store.pullFromCloud();
    await Future<void>.delayed(Duration.zero);
    final added = store.addCustomer('New local customer', '');
    cloud.gate!.complete();
    expect((await pending).isSuccess, isFalse);
    expect(store.customers, contains(added));
  });
}
