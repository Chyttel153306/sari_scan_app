import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/widgets/guided_tutorial.dart';
import 'package:sari_scan_app/src/store/app_store.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final family in ['PlusJakartaSans', 'SpaceGrotesk']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });

  for (final largeText in [false, true]) {
    testWidgets(
      'spotlights follow real controls and fit phone, large text: $largeText',
      (tester) async {
        tester.view.physicalSize = Size(
          largeText ? 320 : 390,
          largeText ? 640 : 844,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = largeText
            ? 1.5
            : 1;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = AppStore();
        addTearDown(store.dispose);
        await store.openSecureSession('My Store');
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(largeText ? 1.5 : 1),
              ),
              child: SariScanApp(store: store),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final titles = [
          'Your products live here',
          'Start with your first item',
          'Ready to sell?',
          'Scan to find it faster',
          'Check the cart, then charge',
          'Keep track of utang',
          'See how your store is doing',
          'Make it your store',
        ];
        for (var i = 0; i < titles.length; i++) {
          expect(find.text(titles[i]), findsOneWidget);
          expect(tester.takeException(), isNull);
          final tour = tester.widget<GuidedTutorial>(
            find.byType(GuidedTutorial),
          );
          final render =
              tour.targets[i].currentContext!.findRenderObject()! as RenderBox;
          expect(render.size.isEmpty, isFalse);
          if (i == 1) {
            await tester.ensureVisible(find.text('Back'));
            await tester.tap(find.text('Back'));
            await tester.pumpAndSettle();
            expect(find.text(titles[0]), findsOneWidget);
            await tester.ensureVisible(find.text('Next'));
            await tester.tap(find.text('Next'));
            await tester.pumpAndSettle();
          }
          if (const bool.fromEnvironment('CAPTURE_TUTORIAL') &&
              !largeText &&
              (i == 0 || i == 3)) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('build/tutorial_preview').create(recursive: true);
              await File(
                'build/tutorial_preview/step_$i.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          final button = find.text(
            i == titles.length - 1 ? 'Start using SariScan' : 'Next',
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
        }
        expect(find.byType(GuidedTutorial), findsNothing);
        expect(store.products, isEmpty);
        expect(store.sales, isEmpty);
        expect(store.customers, isEmpty);
      },
    );
  }
}
