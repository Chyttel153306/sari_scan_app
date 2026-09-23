// Run with: dart run tool/generate_launcher_icons.dart
// Derives all sizes from the approved transparent SariScan artwork.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

img.Image trim(img.Image source) {
  var left = source.width, top = source.height, right = 0, bottom = 0;
  for (final pixel in source) {
    if (pixel.a > 8) {
      left = math.min(left, pixel.x);
      top = math.min(top, pixel.y);
      right = math.max(right, pixel.x);
      bottom = math.max(bottom, pixel.y);
    }
  }
  if (left > right) throw StateError('Logo contains no visible pixels.');
  return img.copyCrop(
    source,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

Future<void> save(String path, img.Image image) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(img.encodePng(image));
}

Future<void> main() async {
  final source = img.decodePng(
    await File('assets/branding/sariscan_logo_source.png').readAsBytes(),
  )!;
  if (source.numChannels != 4 || source.getPixel(0, 0).a != 0) {
    throw StateError(
      'Use the transparent master, without a checkerboard background.',
    );
  }
  final logo = trim(source);
  // Locate the transparent separation between storefront and wordmark.
  var gapStart = 0, gapLength = 0, bestLength = 0, split = 0;
  for (
    var y = (logo.height * .55).round();
    y < (logo.height * .85).round();
    y++
  ) {
    var occupied = false;
    for (var x = 0; x < logo.width; x++) {
      if (logo.getPixel(x, y).a > 8) {
        occupied = true;
        break;
      }
    }
    if (!occupied) {
      if (gapLength == 0) gapStart = y;
      gapLength++;
      if (gapLength > bestLength) {
        bestLength = gapLength;
        split = gapStart + gapLength ~/ 2;
      }
    } else {
      gapLength = 0;
    }
  }
  if (bestLength < 4) {
    throw StateError('Cannot find the gap above the wordmark.');
  }
  final symbol = trim(
    img.copyCrop(logo, x: 0, y: 0, width: logo.width, height: split),
  );
  await save('assets/branding/sariscan_logo.png', logo);
  await save('assets/branding/sariscan_symbol.png', symbol);

  Future<void> icon(
    String path,
    int size, {
    bool transparent = false,
    double scale = .78,
  }) async {
    final canvas = img.Image(
      width: size,
      height: size,
      numChannels: transparent ? 4 : 3,
    );
    img.fill(
      canvas,
      color: transparent
          ? img.ColorRgba8(0, 0, 0, 0)
          : img.ColorRgb8(255, 255, 255),
    );
    final mark = img.copyResize(
      symbol,
      width: (size * scale).round(),
      interpolation: img.Interpolation.average,
    );
    img.compositeImage(
      canvas,
      mark,
      dstX: (size - mark.width) ~/ 2,
      dstY: (size - mark.height) ~/ 2,
    );
    await save(path, canvas);
  }

  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };
  for (final entry in densities.entries) {
    final dir = 'android/app/src/main/res/mipmap-${entry.key}';
    await icon('$dir/ic_launcher.png', (48 * entry.value).round());
    await icon(
      '$dir/ic_launcher_foreground.png',
      (108 * entry.value).round(),
      transparent: true,
      scale: .56,
    );
    await save(
      '$dir/launch_image.png',
      img.copyResize(
        logo,
        width: (180 * entry.value).round(),
        interpolation: img.Interpolation.average,
      ),
    );
  }
  await File(
    'android/app/src/main/res/drawable/ic_launcher_background.xml',
  ).writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#FFFFFF" />
</shape>
''');
  const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  final manifest =
      jsonDecode(await File('$ios/Contents.json').readAsString()) as Map;
  for (final entry in manifest['images'] as List) {
    final size = double.parse((entry['size'] as String).split('x').first);
    final scale = double.parse((entry['scale'] as String).replaceAll('x', ''));
    await icon('$ios/${entry['filename']}', (size * scale).round());
  }
  for (final scale in [1, 2, 3]) {
    final suffix = scale == 1 ? '' : '@${scale}x';
    await save(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
      img.copyResize(
        logo,
        width: 180 * scale,
        interpolation: img.Interpolation.average,
      ),
    );
  }
  for (final size in [192, 512]) {
    await icon('web/icons/Icon-$size.png', size);
    await icon('web/icons/Icon-maskable-$size.png', size, scale: .60);
  }
  await icon('web/favicon.png', 32, scale: .90);
  stdout.writeln(
    'Generated logo ${logo.width}x${logo.height}, symbol ${symbol.width}x${symbol.height}, and Android/iOS/web icons.',
  );
}
