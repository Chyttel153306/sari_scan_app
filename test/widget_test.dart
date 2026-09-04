import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/services/phone_security_service.dart';

class _FakePhoneSecurity implements PhoneSecurityAuthenticator {
  const _FakePhoneSecurity(this.result);

  final PhoneSecurityResult result;

  @override
  Future<PhoneSecurityResult> authenticate() async => result;
}

void main() {
  testWidgets('opens the SariScan login screen', (tester) async {
    await tester.pumpWidget(const SariScanApp());

    expect(find.text('SariScan'), findsOneWidget);
    expect(find.text("Your Store's Best Friend"), findsOneWidget);
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
      find.widgetWithText(TextFormField, 'Your Name'),
      'Maria Santos',
    );
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
      find.widgetWithText(TextFormField, 'Your Name'),
      'Maria Santos',
    );
    await tester.tap(find.text('Continue with Phone Security'));
    await tester.pumpAndSettle();

    expect(find.text('Authentication cancelled.'), findsOneWidget);
    expect(find.text('Tindahan POS'), findsNothing);
  });
}
