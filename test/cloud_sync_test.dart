import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/services/local_storage_service.dart';
import 'package:sari_scan_app/src/services/supabase_image_service.dart';
import 'package:sari_scan_app/src/services/supabase_sync_service.dart';
import 'package:sari_scan_app/src/store/app_store.dart';

class MemoryCloud extends Fake implements SupabaseSyncService {
  Map<String, dynamic> snapshot = {};

  @override
  Future<String> createSyncCode(Map<String, dynamic> data) async {
    snapshot = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    return 'STORE123';
  }

  @override
  Future<DateTime> uploadSnapshot({
    required String syncCode,
    required Map<String, dynamic> snapshot,
  }) async {
    this.snapshot = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    return DateTime(2026, 9, 23);
  }

  @override
  Future<CloudSnapshot?> downloadSnapshot(
    String syncCode, {
    bool join = false,
  }) async => CloudSnapshot(data: snapshot, updatedAt: DateTime(2026, 9, 23));
}

class MemoryImages extends Fake implements SupabaseImageService {
  final files = <String, List<int>>{};
  bool failUpload = false;
  bool failDownload = false;
  int downloads = 0;

  @override
  Future<String> uploadImage(
    String localFilePath, {
    required String syncCode,
  }) async {
    if (failUpload) throw StateError('Upload denied');
    final path = '$syncCode/photo${files.length}.jpg';
    files[path] = await File(localFilePath).readAsBytes();
    return path;
  }

  @override
  Future<List<int>> downloadImageBytes(String reference) async {
    downloads++;
    if (failDownload) throw StateError('Download denied');
    return files[reference]!;
  }

  @override
  void dispose() {}
}

void main() {
  late Directory directory;
  late MemoryCloud cloud;
  late MemoryImages images;
  late AppStore sender;
  late AppStore receiver;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sariscan_sync_');
    final source = File('${directory.path}/source.jpg');
    await source.writeAsBytes([1, 2, 3]);
    cloud = MemoryCloud();
    images = MemoryImages();
    sender = AppStore(
      storage: LocalStorageService(File('${directory.path}/sender/store.json')),
      cloudSync: cloud,
      imageSync: images,
      products: [
        Product(
          id: '1',
          name: 'Rice',
          category: 'Food',
          price: 50,
          stock: 5,
          imagePath: source.path,
        ),
      ],
      customers: [Customer(id: '1', name: 'Maria')],
    );
    receiver = AppStore(
      storage: LocalStorageService(
        File('${directory.path}/receiver/store.json'),
      ),
      cloudSync: cloud,
      imageSync: images,
    );
  });

  tearDown(() async {
    await sender.persistenceSettled;
    await receiver.persistenceSettled;
    sender.dispose();
    receiver.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'creating a code transfers existing photos, sales and utang to another phone',
    () async {
      sender.addToCart(sender.products.single);
      sender.completeSale(
        paymentType: PaymentType.utang,
        customer: sender.customers.single,
      );
      sender.recordPayment(sender.customers.single, 20);
      final result = await sender.startCloudSync();
      expect(result.isSuccess, isTrue);
      expect(result.warning, isNull);
      expect(cloud.snapshot, isNot(contains('account')));
      final row = (cloud.snapshot['products'] as List).single as Map;
      expect(row['image_url'], startsWith('STORE123/'));
      expect(row, isNot(contains('image_path')));

      expect(
        (await receiver.joinCloudSync(result.syncCode!)).isSuccess,
        isTrue,
      );
      expect(receiver.products.single.stock, 4);
      expect(receiver.customers.single.balance, 30);
      expect(receiver.sales, hasLength(1));
      final localPhoto = receiver.products.single.imagePath!;
      expect(localPhoto, isNot(sender.products.single.imagePath));
      expect(await File(localPhoto).readAsBytes(), [1, 2, 3]);
      await receiver.pullFromCloud();
      expect(
        images.downloads,
        1,
        reason: 'Keep the receiving phone photo cache',
      );
    },
  );

  test(
    'upload reports photo failures and retries them with the next upload',
    () async {
      images.failUpload = true;
      final result = await sender.startCloudSync();
      expect(result.isSuccess, isTrue);
      expect(result.warning, contains('1 photo(s) could not upload'));
      expect(sender.products.single.imageUrl, isNull);
      expect(cloud.snapshot['products'], hasLength(1));

      images.failUpload = false;
      final retry = await sender.pushToCloud();
      expect(retry.warning, isNull);
      expect(sender.products.single.imageUrl, isNotNull);
      await receiver.joinCloudSync('STORE123');
      expect(receiver.products.single.imagePath, isNotNull);
    },
  );

  test(
    'download reports photo failures while preserving data and retries later',
    () async {
      await sender.startCloudSync();
      images.failDownload = true;
      final result = await receiver.joinCloudSync('STORE123');
      expect(result.isSuccess, isTrue);
      expect(result.warning, contains('1 photo(s) could not download'));
      expect(receiver.products.single.name, 'Rice');
      expect(receiver.products.single.imagePath, isNull);

      images.failDownload = false;
      expect((await receiver.pullFromCloud()).warning, isNull);
      expect(await File(receiver.products.single.imagePath!).readAsBytes(), [
        1,
        2,
        3,
      ]);
    },
  );

  test(
    'unlink clears local records and photos; the code restores the cloud store',
    () async {
      sender.addToCart(sender.products.single);
      sender.completeSale(
        paymentType: PaymentType.utang,
        customer: sender.customers.single,
      );
      await sender.startCloudSync();
      await receiver.joinCloudSync('STORE123');
      final cachedPhoto = File(receiver.products.single.imagePath!);
      final savedCloud = jsonEncode(cloud.snapshot);
      final savedImages = images.files.length;
      receiver.addToCart(receiver.products.single);

      expect(await receiver.leaveCloudSync(), isNull);
      expect(receiver.products, isEmpty);
      expect(receiver.customers, isEmpty);
      expect(receiver.sales, isEmpty);
      expect(receiver.stockAdditions, isEmpty);
      expect(receiver.cartItemCount, 0);
      expect(receiver.syncCode, isNull);
      expect(await cachedPhoto.exists(), isFalse);
      expect(jsonEncode(cloud.snapshot), savedCloud);
      expect(images.files.length, savedImages);

      final restarted = AppStore(storage: receiver.storage);
      await restarted.initialize();
      expect(restarted.products, isEmpty);
      expect(restarted.customers, isEmpty);
      expect(restarted.sales, isEmpty);
      expect(restarted.syncCode, isNull);
      restarted.dispose();

      expect((await receiver.joinCloudSync('STORE123')).isSuccess, isTrue);
      expect(receiver.products.single.name, 'Rice');
      expect(receiver.customers.single.balance, 50);
      expect(receiver.sales, hasLength(1));
      expect(await File(receiver.products.single.imagePath!).readAsBytes(), [
        1,
        2,
        3,
      ]);
    },
  );

  test(
    'ignores a foreign file path even if it exists on the receiving phone',
    () async {
      await sender.startCloudSync();
      final row = (cloud.snapshot['products'] as List).single as Map;
      row['image_path'] = sender.products.single.imagePath;
      await receiver.joinCloudSync('STORE123');
      expect(images.downloads, 1);
      expect(
        receiver.products.single.imagePath,
        isNot(sender.products.single.imagePath),
      );
    },
  );
}
