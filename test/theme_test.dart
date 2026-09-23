import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/screens/settings_screen.dart';
import 'package:sari_scan_app/src/services/local_storage_service.dart';
import 'package:sari_scan_app/src/store/app_store.dart';
import 'package:sari_scan_app/src/theme/app_theme.dart';
import 'package:sari_scan_app/src/theme/theme_choice.dart';

void main() {
  test(
    'theme survives restart and old or unknown values use Default',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sariscan_theme_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = LocalStorageService(File('${directory.path}/store.json'));
      final store = AppStore(storage: storage);
      addTearDown(store.dispose);

      for (final choice in ThemeChoice.values) {
        expect(await store.updateTheme(choice), isNull);
        final restored = AppStore(storage: storage);
        await restored.initialize();
        expect(restored.themeChoice, choice);
        restored.dispose();
      }

      for (final value in [null, 'future-theme']) {
        final snapshot = (await storage.loadSnapshot())!;
        if (value == null) {
          snapshot.remove('theme');
        } else {
          snapshot['theme'] = value;
        }
        await storage.saveSnapshot(snapshot);
        final restored = AppStore(storage: storage);
        await restored.initialize();
        expect(restored.themeChoice, ThemeChoice.defaultTheme);
        expect(restored.storageError, isNull);
        restored.dispose();
      }
    },
  );

  testWidgets(
    'Settings changes every theme without leaving the current route',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = AppStore();
      addTearDown(store.dispose);
      await store.openSecureSession('Owner');
      await tester.pumpWidget(SariScanApp(store: store));
      await tester.tap(find.byTooltip('Store account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      await tester.pumpAndSettle();

      for (final choice in [
        ThemeChoice.dark,
        ThemeChoice.blue,
        ThemeChoice.red,
        ThemeChoice.pink,
        ThemeChoice.defaultTheme,
      ]) {
        await tester.ensureVisible(find.text('Appearance'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Appearance'));
        await tester.pumpAndSettle();
        final option = find.byKey(ValueKey('theme-${choice.name}'));
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(store.themeChoice, choice);
        expect(find.text('${choice.label} theme'), findsOneWidget);
        final context = tester.element(find.text('Appearance'));
        final theme = Theme.of(context);
        expect(theme.colorScheme.primary, AppPalette.forChoice(choice).emerald);
        expect(
          theme.brightness,
          choice == ThemeChoice.dark ? Brightness.dark : Brightness.light,
        );
        expect(AppTheme.of(context).base, theme.scaffoldBackgroundColor);
        expect(tester.takeException(), isNull);
      }
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .colorScheme
            .primary,
        AppTheme.emerald,
      );
    },
  );
}
