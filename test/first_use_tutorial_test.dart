import 'package:flutter/services.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/widgets/guided_tutorial.dart';
import 'package:sari_scan_app/src/services/local_storage_service.dart';
import 'package:sari_scan_app/src/store/app_store.dart';

void main() {
  setUpAll(() async {
    for (final family in ['PlusJakartaSans', 'SpaceGrotesk']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });
  test(
    'tutorial dismissal survives restart and existing accounts opt out',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sariscan_tutorial_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = LocalStorageService(File('${directory.path}/store.json'));
      final first = AppStore(storage: storage);
      addTearDown(first.dispose);
      await first.initialize();
      await first.openSecureSession('Owner');
      expect(first.needsFirstUseTutorial, isTrue);
      expect(await first.dismissTutorial(), isNull);

      final restored = AppStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.initialize();
      await restored.openSecureSession('Owner');
      expect(restored.needsFirstUseTutorial, isFalse);

      final legacy = (await storage.loadSnapshot())!
        ..remove('tutorial_dismissed');
      await storage.saveSnapshot(legacy);
      final existing = AppStore(storage: storage);
      addTearDown(existing.dispose);
      await existing.initialize();
      expect(existing.needsFirstUseTutorial, isFalse);
    },
  );

  testWidgets('first sign-in can skip and later visits can reopen the guide', (
    tester,
  ) async {
    final store = AppStore();
    addTearDown(store.dispose);
    await store.openSecureSession('Owner');
    await tester.pumpWidget(SariScanApp(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(GuidedTutorial), findsOneWidget);
    await tester.tap(find.text('Skip tutorial'));
    await tester.pumpAndSettle();
    expect(store.needsFirstUseTutorial, isFalse);
    expect(find.text('Tindahan POS'), findsOneWidget);

    await store.logout();
    await tester.pumpAndSettle();
    await store.openSecureSession('Owner');
    await tester.pumpAndSettle();
    expect(find.byType(GuidedTutorial), findsNothing);
    await tester.tap(find.byTooltip('App tutorial'));
    await tester.pumpAndSettle();
    expect(find.byType(GuidedTutorial), findsOneWidget);
    expect(find.text('Skip tutorial'), findsOneWidget);
  });

  testWidgets('finishing first-use tutorial also dismisses it', (tester) async {
    final store = AppStore();
    addTearDown(store.dispose);
    await store.openSecureSession('Owner');
    await tester.pumpWidget(SariScanApp(store: store));
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Start using SariScan'));
    await tester.pumpAndSettle();
    expect(store.needsFirstUseTutorial, isFalse);
    expect(find.text('Tindahan POS'), findsOneWidget);
  });
}
