import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sari_scan_app/src/services/supabase_sync_service.dart';
import 'package:sari_scan_app/src/services/supabase_image_service.dart';
import 'package:sari_scan_app/src/services/local_storage_service.dart';
import 'package:sari_scan_app/src/store/app_store.dart';

const userId = '00000000-0000-0000-0000-000000000001';
Map<String, dynamic> authResponse() {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': userId,
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'role': 'authenticated',
          }),
        ),
      )
      .replaceAll('=', '');
  return {
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
    'refresh_token': 'refresh',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}

class WaitingImages extends Fake implements SupabaseImageService {
  final gate = Completer<List<int>>();
  @override
  Future<List<int>> downloadImageBytes(String reference) => gate.future;
  @override
  void dispose() {}
}

void main() {
  SupabaseClient client(http.Client transport) => SupabaseClient(
    'https://audit.invalid',
    'public-key',
    httpClient: transport,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  test('cloud authentication has a bounded timeout', () async {
    final gate = Completer<http.Response>();
    final transport = MockClient((_) => gate.future);
    final api = client(transport);
    addTearDown(api.dispose);
    final service = SupabaseSyncService(
      client: api,
      requestTimeout: const Duration(milliseconds: 30),
    );
    await expectLater(
      service.createSyncCode({}),
      throwsA(isA<TimeoutException>()),
    );
    gate.complete(http.Response(jsonEncode(authResponse()), 200));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });

  for (final response in ['null', '123', '""']) {
    test(
      'malformed create-store response cannot become a saved sync code: $response',
      () async {
        final transport = MockClient(
          (request) async => http.Response(
            request.url.path.contains('/auth/')
                ? jsonEncode(authResponse())
                : response,
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        final api = client(transport);
        addTearDown(api.dispose);
        await expectLater(
          SupabaseSyncService(client: api).createSyncCode({}),
          throwsA(isA<CloudSyncException>()),
        );
      },
    );
  }

  test('legacy image download has a bounded timeout', () async {
    final gate = Completer<http.Response>();
    final transport = MockClient((_) => gate.future);
    final api = client(transport);
    addTearDown(api.dispose);
    final service = SupabaseImageService(
      client: api,
      httpClient: transport,
      requestTimeout: const Duration(milliseconds: 30),
    );
    await expectLater(
      service.downloadImageBytes('https://i.ibb.co/photo.jpg'),
      throwsA(isA<TimeoutException>()),
    );
    gate.complete(http.Response('bytes', 200));
  });

  test(
    'startup does not wait for remote photos and caches paths when finished',
    () async {
      final dir = await Directory.systemTemp.createTemp('sariscan_startup_');
      addTearDown(() => dir.delete(recursive: true));
      final storage = LocalStorageService(File('${dir.path}/store.json'));
      await storage.saveSnapshot({
        'version': 3,
        'products': [
          {
            'id': '1',
            'name': 'Rice',
            'category': 'Food',
            'price': 10,
            'stock': 1,
            'image_url': 'STORE123/photo.jpg',
          },
        ],
        'customers': [],
        'sales': [],
      });
      final images = WaitingImages();
      final store = AppStore(storage: storage, imageSync: images);
      addTearDown(store.dispose);
      await store.initialize().timeout(const Duration(milliseconds: 200));
      expect(store.isLoading, isFalse);
      expect(store.products.single.imagePath, isNull);
      images.gate.complete([1, 2, 3]);
      await store.photoRestorationSettled;
      expect(await File(store.products.single.imagePath!).exists(), isTrue);
      expect(
        ((await storage.loadSnapshot())!['products'] as List)
            .single['image_path'],
        store.products.single.imagePath,
      );
    },
  );
}
