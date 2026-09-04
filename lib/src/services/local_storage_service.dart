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
    final source = await file.exists() ? file : File('${file.path}.bak');
    if (!await source.exists()) return null;

    final decoded = jsonDecode(await source.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The local SariScan data file is invalid.');
    }
    return decoded;
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
      await backup.delete();
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

  Future<void> deleteProductImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    final image = File(imagePath);
    if (await image.exists()) await image.delete();
  }
}
