import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sari_scan_app/src/widgets/product_image.dart';

void main() {
  testWidgets('portrait photos decode within both thumbnail dimensions', (
    tester,
  ) async {
    // File I/O and the image decoder must run outside the fake test clock.
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp(
        'sariscan_image_',
      );
      try {
        final file = await File(
          '${directory.path}/portrait.png',
        ).writeAsBytes(img.encodePng(img.Image(width: 200, height: 2000)));
        await tester.pumpWidget(
          MaterialApp(
            home: ProductImage(
              imagePath: file.path,
              fit: BoxFit.contain,
              cacheWidth: 100,
              cacheHeight: 100,
            ),
          ),
        );
        final provider = tester.widget<Image>(find.byType(Image)).image;
        final result = Completer<ImageInfo>();
        final stream = provider.resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (image, _) => result.complete(image),
          onError: (Object error, StackTrace? stack) =>
              result.completeError(error, stack),
        );
        stream.addListener(listener);
        try {
          final info = await result.future.timeout(const Duration(seconds: 10));
          expect(info.image.width, 10);
          expect(info.image.height, 100);
          info.dispose();
        } finally {
          stream.removeListener(listener);
          await tester.pumpWidget(const SizedBox.shrink());
          await provider.evict();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });
}
