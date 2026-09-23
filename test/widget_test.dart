import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/services/phone_security_service.dart';
import 'package:sari_scan_app/src/widgets/design_system.dart';

class _FakePhoneSecurity implements PhoneSecurityAuthenticator {
  const _FakePhoneSecurity(this.result);

  final PhoneSecurityResult result;

  @override
  Future<PhoneSecurityResult> authenticate() async => result;
}

void main() {
  setUpAll(() async {
    for (final family in ['PlusJakartaSans', 'SpaceGrotesk']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });

  testWidgets('opens the SariScan login screen', (tester) async {
    await tester.pumpWidget(const SariScanApp());
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(BrandMark.logoAsset),
        tester.element(find.byType(BrandMark)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BrandMark), findsOneWidget);
    expect(tester.widget<BrandMark>(find.byType(BrandMark)).wordmark, isTrue);
    expect(
      tester
          .widget<RawImage>(
            find.descendant(
              of: find.byType(BrandMark),
              matching: find.byType(RawImage),
            ),
          )
          .image,
      isNotNull,
    );
    expect(find.text('Scan. Sell. Track'), findsOneWidget);
    expect(find.text('Continue with Phone Security'), findsOneWidget);
  });

  testWidgets('a fresh phone creates its owner only after phone security', (
    tester,
  ) async {
    await tester.pumpWidget(
      const SariScanApp(
        phoneSecurity: _FakePhoneSecurity(PhoneSecurityResult.success()),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Store Name'),
      'Maria Santos',
    );
    await tester.ensureVisible(find.text('Continue with Phone Security'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Phone Security'));
    await tester.pumpAndSettle();

    expect(find.text('Tindahan POS'), findsOneWidget);
    expect(find.text('No matching products found.'), findsOneWidget);
  });

  testWidgets('cancelled phone security does not create a session', (
    tester,
  ) async {
    await tester.pumpWidget(
      const SariScanApp(
        phoneSecurity: _FakePhoneSecurity(
          PhoneSecurityResult.failure('Authentication cancelled.'),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Store Name'),
      'Maria Santos',
    );
    await tester.ensureVisible(find.text('Continue with Phone Security'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Phone Security'));
    await tester.pumpAndSettle();

    expect(find.text('Authentication cancelled.'), findsOneWidget);
    expect(find.text('Tindahan POS'), findsNothing);
  });
}
