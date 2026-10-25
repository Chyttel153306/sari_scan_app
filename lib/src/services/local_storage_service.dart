import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  LocalStorageService(this.file);

  static const fileName = 'sariscan_store.json';

  final File file;

  static Future<LocalStorageService> create() async {
    final directory = await getApplicationSupportDirectory();
    return LocalStorageService(
      File('${directory.path}${Platform.pathSeparator}$fileName'),
    );
  }

  Future<Map<String, dynamic>?> loadSnapshot() async {
    Object? firstError;
    for (final source in [file, File('${file.path}.bak')]) {
      try {
        if (!await source.exists()) continue;
        final decoded = jsonDecode(await source.readAsString());
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException(
            'The local SariScan data file is invalid.',
          );
        }
        return decoded;
      } catch (error) {
        firstError ??= error;
      }
    }
    if (firstError != null) throw firstError;
    return null;
  }

  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    await temporary.writeAsString(jsonEncode(snapshot), flush: true);

    if (!await file.exists()) {
      await temporary.rename(file.path);
      return;
    }

    if (await backup.exists()) await backup.delete();
    await file.rename(backup.path);
    try {
      await temporary.rename(file.path);
      // Keep the last complete snapshot available for corruption recovery.
    } catch (_) {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }

  Future<String> importProductImage(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('The selected product photo is missing.');
    }
    final imageDirectory = Directory(
      '${file.parent.path}${Platform.pathSeparator}product_images',
    );
    await imageDirectory.create(recursive: true);
    final dot = source.path.lastIndexOf('.');
    final extension = dot >= 0
        ? source.path.substring(dot).toLowerCase()
        : '.jpg';
    final destination = File(
      '${imageDirectory.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await source.copy(destination.path);
    return destination.path;
  }

  /// Saves raw image bytes — e.g. downloaded from a synced product's
  /// ImgBB URL — into the same local product_images folder used by
  /// [importProductImage], so a downloaded photo displays and gets
  /// cleaned up exactly like a locally-imported one.
  Future<String> saveImageBytes(
    List<int> bytes, {
    String extension = '.jpg',
  }) async {
    final imageDirectory = Directory(
      '${file.parent.path}${Platform.pathSeparator}product_images',
    );
    await imageDirectory.create(recursive: true);
    final destination = File(
      '${imageDirectory.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await destination.writeAsBytes(bytes, flush: true);
    return destination.path;
  }

  Future<void> deleteProductImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    final cache = Directory(
      '${file.parent.path}${Platform.pathSeparator}product_images',
    );
    if (!await cache.exists()) return;
    // Never follow a snapshot-supplied path to another file or a symbolic link.
    if (await FileSystemEntity.type(imagePath, followLinks: false) !=
        FileSystemEntityType.file) {
      return;
    }
    final root = await file.parent.resolveSymbolicLinks();
    final cachePath = await cache.resolveSymbolicLinks();
    final image = File(imagePath);
    final resolved = await image.resolveSymbolicLinks();
    String normalized(String path) =>
        Platform.isWindows ? path.toLowerCase() : path;
    final expectedCache = '$root${Platform.pathSeparator}product_images';
    if (normalized(cachePath) != normalized(expectedCache) ||
        !normalized(
          resolved,
        ).startsWith(normalized('$cachePath${Platform.pathSeparator}'))) {
      return;
    }
    await image.delete();
  }

  /// Clears only this app's managed photo cache, never cloud objects or
  /// source photos selected from the phone's gallery.
  Future<void> clearProductImages() async {
    final directory = Directory(
      '${file.parent.path}${Platform.pathSeparator}product_images',
    );
    if (!await directory.exists()) return;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File || entry is Link) await entry.delete();
    }
  }
}
