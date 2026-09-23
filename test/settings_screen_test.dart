import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/screens/login_screen.dart';
import 'package:sari_scan_app/src/screens/settings_screen.dart';
import 'package:sari_scan_app/src/services/local_storage_service.dart';
import 'package:sari_scan_app/src/services/supabase_sync_service.dart';
import 'package:sari_scan_app/src/store/app_store.dart';
import 'package:sari_scan_app/src/theme/app_theme.dart';
import 'package:sari_scan_app/src/theme/theme_choice.dart';

class _UnavailableStorage extends LocalStorageService {
  _UnavailableStorage() : super(File('unused.json'));

  @override
  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    throw const FileSystemException('Storage is full');
  }
}

class _Cloud extends Fake implements SupabaseSyncService {}

Future<void> _open(WidgetTester tester, AppStore store) => tester.pumpWidget(
  ListenableBuilder(
    listenable: store,
    builder: (context, _) => MaterialApp(
      theme: AppTheme.forChoice(store.themeChoice),
      home: SettingsScreen(store: store),
    ),
  ),
);

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
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

  testWidgets('confirmed logout closes Settings and returns to sign in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore();
    addTearDown(store.dispose);
    await store.openSecureSession('Maria Store');
    await tester.pumpWidget(SariScanApp(store: store));
    await tester.tap(find.byTooltip('Store account'));
    await tester.pumpAndSettle();
    await _tap(tester, 'Settings');
    await _tap(tester, 'Log out');
    await _tap(tester, 'Log out');
    expect(store.isAuthenticated, isFalse);
    expect(store.registeredOwnerName, 'Maria Store');
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('markup preference survives restarting the store', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sariscan_settings_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final storage = LocalStorageService(File('${directory.path}/store.json'));
    final store = AppStore(storage: storage);
    addTearDown(store.dispose);
    expect(await store.updateMarkupPercent(12.5), isNull);
    final restored = AppStore(storage: storage);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.markupPercent, 12.5);
  });

  testWidgets(
    'markup previews, protects unsaved edits, and keeps saved value',
    (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      await _open(tester, store);
      await _tap(tester, 'Default markup');
      await tester.enterText(find.byType(TextField), '25');
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(find.textContaining('125.00'), findsOneWidget);
      await _tap(tester, 'Cancel');
      expect(find.text('Discard markup changes?'), findsOneWidget);
      await _tap(tester, 'Keep editing');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '25',
      );
      await _tap(tester, 'Save markup');
      expect(store.markupPercent, 25);
      expect(
        find.text('25% added to cost for suggested prices'),
        findsOneWidget,
      );
      await _tap(tester, 'Default markup');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '25',
      );
      await tester.enterText(find.byType(TextField), '30');
      await tester.pumpAndSettle();
      await _tap(tester, 'Cancel');
      await _tap(tester, 'Discard');
      expect(store.markupPercent, 25);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed markup save remains editable and restores saved value', (
    tester,
  ) async {
    final store = AppStore(storage: _UnavailableStorage());
    addTearDown(store.dispose);
    await _open(tester, store);
    await _tap(tester, 'Default markup');
    await tester.enterText(find.byType(TextField), '20');
    await tester.pumpAndSettle();
    await _tap(tester, 'Save markup');
    expect(store.markupPercent, 10);
    expect(find.textContaining('Storage is full'), findsWidgets);
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('failed theme save restores the selected theme', () async {
    final store = AppStore(storage: _UnavailableStorage());
    addTearDown(store.dispose);
    expect(await store.updateTheme(ThemeChoice.pink), isNotNull);
    expect(store.themeChoice, ThemeChoice.defaultTheme);
  });

  testWidgets('unlink and logout require confirmation', (tester) async {
    final store = AppStore(cloudSync: _Cloud());
    addTearDown(store.dispose);
    await store.openSecureSession('Maria Store');
    store.syncCode = 'STORE123';
    await _open(tester, store);
    await _tap(tester, 'Unlink this phone');
    expect(find.text('Unlink this phone?'), findsOneWidget);
    expect(store.syncCode, 'STORE123');
    await _tap(tester, 'Cancel');
    expect(store.syncCode, 'STORE123');
    await _tap(tester, 'Log out');
    expect(find.text('Log out of SariScan?'), findsOneWidget);
    expect(store.isAuthenticated, isTrue);
    await _tap(tester, 'Cancel');
    expect(store.isAuthenticated, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final choice in [ThemeChoice.defaultTheme, ThemeChoice.dark]) {
    testWidgets(
      'settings and sheets fit a small screen with large text: ${choice.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = AppStore(cloudSync: _Cloud());
        addTearDown(store.dispose);
        await store.openSecureSession('Maria and Family Neighborhood Store');
        await store.updateTheme(choice);
        await _open(tester, store);
        await _tap(tester, 'Appearance');
        await _tap(tester, 'Pink');
        await _tap(tester, 'Default markup');
        await tester.enterText(find.byType(TextField), '15');
        await tester.pumpAndSettle();
        await _tap(tester, 'Save markup');
        await _tap(tester, 'Set up cloud sync');
        expect(find.text('Create sync code'), findsOneWidget);
        expect(find.text('Join with a code'), findsOneWidget);
        Navigator.of(tester.element(find.text('Sync this store'))).pop();
        await tester.pumpAndSettle();
        await _tap(tester, 'Help & FAQ');
        await _tap(tester, 'Done');
        await _tap(tester, 'Log out');
        await _tap(tester, 'Cancel');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
