import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mirrors product photos to Supabase Storage so they can follow a product
/// across phones during cloud sync — [AppStore]'s cloud sync only moves the
/// snapshot, and a product's local file path only ever resolves on the phone
/// that originally took the picture.
///
/// Photos are stored in the private `product-images` bucket under
/// `<SYNC_CODE>/<file>`, and that path is what [Product.imageUrl] holds.
/// Storage policies must restrict access to members of the store.
///
/// Values that start with `http` are legacy ImgBB URLs from before the
/// migration. They are still readable here so existing photos can be moved
/// over once with "Upload existing photos now" in Settings; after that this
/// legacy branch (and the `http` package) can be removed.
class SupabaseImageService {
  SupabaseImageService({
    SupabaseClient? client,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _client = client ?? Supabase.instance.client,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  final SupabaseClient _client;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration requestTimeout;

  static const bucket = 'product-images';

  static const _contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  /// True for an old ImgBB-style web URL rather than a Storage path.
  static bool isLegacyUrl(String reference) =>
      reference.startsWith('http://') || reference.startsWith('https://');

  /// Ensures a Supabase session exists before accessing the private photo bucket.
  Future<void> _ensureSignedIn() async {
    if (_client.auth.currentSession != null) return;
    await _client.auth.signInAnonymously().timeout(requestTimeout);
  }

  /// Chooses a supported upload extension, defaulting to jpg.
  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    final extension = dot >= 0 ? path.substring(dot + 1).toLowerCase() : '';
    return _contentTypes.containsKey(extension) ? extension : 'jpg';
  }

  /// Creates a timestamp and random suffix for a Storage object name.
  static String _uniqueName() {
    final random = Random.secure();
    final suffix = List.generate(
      8,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  /// Uploads the image at [localFilePath] into the store's folder and
  /// returns its Storage path.
  Future<String> uploadImage(
    String localFilePath, {
    required String syncCode,
  }) async {
    final file = File(localFilePath);
    if (!await file.exists()) {
      throw FileSystemException(
        'Image file not found for upload.',
        localFilePath,
      );
    }
    await _ensureSignedIn();
    final bytes = await file.readAsBytes();
    final extension = _extensionOf(localFilePath);
    final path = '$syncCode/${_uniqueName()}.$extension';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypes[extension],
            upsert: false,
          ),
        )
        .timeout(requestTimeout);
    return path;
  }

  /// Downloads the raw bytes of a photo, for saving locally. [reference] is
  /// a Storage path, or a legacy ImgBB URL.
  Future<List<int>> downloadImageBytes(String reference) async {
    if (isLegacyUrl(reference)) {
      final response = await _httpClient
          .get(Uri.parse(reference))
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        throw HttpException(
          'Could not download image (status ${response.statusCode}).',
        );
      }
      return response.bodyBytes;
    }
    await _ensureSignedIn();
    return _client.storage
        .from(bucket)
        .download(reference)
        .timeout(requestTimeout);
  }

  /// Deletes a photo from Storage. Legacy web URLs are ignored — this app
  /// never deletes anything from ImgBB.
  Future<void> deleteImage(String reference) async {
    if (reference.isEmpty || isLegacyUrl(reference)) return;
    await _ensureSignedIn();
    await _client.storage
        .from(bucket)
        .remove([reference])
        .timeout(requestTimeout);
  }

  /// Closes the HTTP client only when this service created it.
  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
  }
}
