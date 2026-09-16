import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Mirrors product photos to ImgBB (a free image host) so they can follow
/// a product across phones during cloud sync — [AppStore]'s cloud sync
/// only moves the JSON snapshot, and a product's local file path only
/// ever resolves on the phone that originally took the picture.
///
/// This is entirely optional and additive: if no API key is configured,
/// [AppStore] simply skips photo syncing and everything else (products,
/// sales, utang) keeps working exactly as before.
///
/// Get a free key at https://api.imgbb.com/ (no credit card required).
class ImgbbImageService {
  ImgbbImageService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _uploadEndpoint = 'https://api.imgbb.com/1/upload';

  /// Uploads the image at [localFilePath] and returns its public URL.
  Future<String> uploadImage(String localFilePath) async {
    final file = File(localFilePath);
    if (!await file.exists()) {
      throw FileSystemException(
        'Image file not found for upload.',
        localFilePath,
      );
    }
    final bytes = await file.readAsBytes();
    final response = await _client.post(
      Uri.parse('$_uploadEndpoint?key=$apiKey'),
      body: {'image': base64Encode(bytes)},
    );
    if (response.statusCode != 200) {
      throw HttpException(
        'ImgBB upload failed with status ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      throw const FormatException('ImgBB upload was not successful.');
    }
    final data = decoded['data'];
    final url = data is Map ? (data['url'] ?? data['display_url']) : null;
    if (url is! String || url.isEmpty) {
      throw const FormatException('ImgBB response did not include a URL.');
    }
    return url;
  }

  /// Downloads the raw bytes of the image at [url], for saving locally.
  Future<List<int>> downloadImageBytes(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw HttpException(
        'Could not download image (status ${response.statusCode}).',
      );
    }
    return response.bodyBytes;
  }

  void dispose() => _client.close();
}