// Run with: flutter test tool/generate_launcher_icons.dart
// Renders the existing login screen's SariScan mark using Material Icons.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sari_scan_app/src/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generate SariScan launcher assets', () async {
    final loader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();

    Future<void> render(
      String path,
      int size, {
      bool foreground = false,
    }) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      if (!foreground) {
        final bounds = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
        canvas.drawRect(
          bounds,
          Paint()..shader = AppTheme.brandGradient.createShader(bounds),
        );
      }
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.storefront_outlined.codePoint),
          style: TextStyle(
            fontFamily: 'MaterialIcons',
            fontSize: size * (foreground ? 48 / 108 : 52 / 96),
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset((size - painter.width) / 2, (size - painter.height) / 2),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      await file.parent.create(recursive: true);
      final png = bytes!.buffer.asUint8List();
      // iOS launcher assets must not contain an alpha channel.
      await file.writeAsBytes(
        foreground
            ? png
            : img.encodePng(img.decodePng(png)!.convert(numChannels: 3)),
      );
      image.dispose();
      picture.dispose();
      painter.dispose();
    }

    await render('assets/branding/sariscan_logo.png', 1024);
    final background = File(
      'android/app/src/main/res/drawable/ic_launcher_background.xml',
    );
    await background.parent.create(recursive: true);
    String hex(Color color) => '#${color.toARGB32().toRadixString(16)}';
    await background.writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="45"
        android:startColor="${hex(AppTheme.brandGradient.colors.first)}"
        android:endColor="${hex(AppTheme.brandGradient.colors.last)}" />
</shape>
''');
    const densities = {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    };
    for (final entry in densities.entries) {
      final directory = 'android/app/src/main/res/mipmap-${entry.key}';
      await render('$directory/ic_launcher.png', (48 * entry.value).round());
      await render(
        '$directory/ic_launcher_foreground.png',
        (108 * entry.value).round(),
        foreground: true,
      );
    }
    const iosDirectory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final manifest =
        jsonDecode(await File('$iosDirectory/Contents.json').readAsString())
            as Map;
    for (final entry in manifest['images'] as List) {
      final size = double.parse((entry['size'] as String).split('x').first);
      final scale = double.parse(
        (entry['scale'] as String).replaceAll('x', ''),
      );
      await render(
        '$iosDirectory/${entry['filename']}',
        (size * scale).round(),
      );
    }
    for (final size in [192, 512]) {
      await render('web/icons/Icon-$size.png', size);
      await render('web/icons/Icon-maskable-$size.png', size);
    }
    await render('web/favicon.png', 32);
  });
}
