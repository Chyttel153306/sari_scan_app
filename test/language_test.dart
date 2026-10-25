import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/l10n/app_language.dart';
import 'package:sari_scan_app/src/l10n/app_localizations.dart';
import 'package:sari_scan_app/src/l10n/translations.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/screens/settings_screen.dart';
import 'package:sari_scan_app/src/services/local_storage_service.dart';
import 'package:sari_scan_app/src/store/app_store.dart';

class _FailingStorage extends LocalStorageService {
  _FailingStorage() : super(File('unused.json'));
  @override
  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    throw const FileSystemException('Storage is full');
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target.last);
  await tester.pumpAndSettle();
  await tester.tap(target.last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final family in ['PlusJakartaSans', 'SpaceGrotesk']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });

  test(
    'each language survives restart; legacy and unknown values use English',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sariscan_language_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = LocalStorageService(File('${directory.path}/store.json'));
      final store = AppStore(storage: storage);
      addTearDown(store.dispose);
      for (final language in AppLanguage.values) {
        expect(await store.updateLanguage(language), isNull);
        final restored = AppStore(storage: storage);
        await restored.initialize();
        expect(restored.language, language);
        expect(restored.storageError, isNull);
        restored.dispose();
      }
      for (final value in [null, 'unknown']) {
        final snapshot = (await storage.loadSnapshot())!;
        if (value == null) {
          snapshot.remove('language');
        } else {
          snapshot['language'] = value;
        }
        await storage.saveSnapshot(snapshot);
        final restored = AppStore(storage: storage);
        await restored.initialize();
        expect(restored.language, AppLanguage.english);
        restored.dispose();
      }
    },
  );

  test('failed save restores the previous language', () async {
    final store = AppStore(storage: _FailingStorage());
    addTearDown(store.dispose);
    expect(
      await store.updateLanguage(AppLanguage.bisaya),
      contains('Storage is full'),
    );
    expect(store.language, AppLanguage.english);
  });

  test('translations preserve dynamic names and matching placeholders', () {
    final placeholder = RegExp(r'\{\d+\}');
    for (final entry in appTranslations.entries) {
      Set<String> placeholders(String value) =>
          placeholder.allMatches(value).map((m) => m[0]!).toSet();
      expect(
        placeholders(entry.value.$1),
        placeholders(entry.key),
        reason: entry.key,
      );
      expect(
        placeholders(entry.value.$2),
        placeholders(entry.key),
        reason: entry.key,
      );
    }
    for (final language in AppLanguage.values) {
      expect(
        AppStrings(language).tr('{0} added to cart.', args: ['Cash {1}']),
        contains('Cash {1}'),
      );
    }
  });

  for (final small in [false, true]) {
    testWidgets(
      'Settings switches all languages immediately and keeps the route (small=$small)',
      (tester) async {
        tester.view.physicalSize = small
            ? const Size(320, 640)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        if (small) tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = AppStore(
          products: [
            Product(
              id: 'p1',
              name: 'Cash',
              category: 'Reports',
              price: 10,
              stock: 3,
            ),
          ],
        );
        addTearDown(store.dispose);
        await store.openSecureSession('My Store');
        await store.dismissTutorial();
        await tester.pumpWidget(SariScanApp(store: store));
        await tester.tap(find.byTooltip('Store account'));
        await tester.pumpAndSettle();
        await tapText(tester, 'Settings');
        var current = AppLanguage.english;
        for (final language in [
          AppLanguage.bisaya,
          AppLanguage.tagalog,
          AppLanguage.english,
        ]) {
          await tapText(tester, AppStrings(current).tr('Language'));
          for (final option in AppLanguage.values) {
            expect(
              find.byKey(ValueKey('language-${option.code}')),
              findsOneWidget,
            );
          }
          expect(
            tester
                .widget<ListTile>(
                  find.byKey(ValueKey('language-${current.code}')),
                )
                .selected,
            isTrue,
          );
          await tester.tap(find.byKey(ValueKey('language-${language.code}')));
          await tester.pumpAndSettle();
          expect(store.language, language);
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(
            find.text(AppStrings(language).tr('Language')),
            findsOneWidget,
          );
          expect(
            find.text(AppStrings(language).tr('Settings')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          current = language;
        }
        // The sheet can be dismissed without changing the saved choice.
        await tapText(tester, 'Language');
        Navigator.of(
          tester.element(find.byKey(const ValueKey('language-en'))),
        ).pop();
        await tester.pumpAndSettle();
        expect(store.language, AppLanguage.english);
        // App-owned labels translate, while names and category filters stay intact.
        await store.updateLanguage(AppLanguage.bisaya);
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Mga Produkto'), findsOneWidget);
        expect(find.text('Cash'), findsOneWidget);
        expect(find.text('Reports'), findsOneWidget);
        expect(find.text('Tanang Produkto'), findsOneWidget);
        await tester.tap(find.text('Cash'));
        await tester.pumpAndSettle();
        expect(store.cartItemCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
