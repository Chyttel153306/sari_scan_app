import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/screens/tutorial_screen.dart';
import 'package:sari_scan_app/src/theme/app_theme.dart';

void main() {
  testWidgets('tutorial supports next, back, topic selection and finish', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const TutorialScreen()),
              ),
              child: const Text('Open guide'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open guide'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 8: Add your first product'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 8: Build a customer order'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 8: Add your first product'), findsOneWidget);
    await tester.tap(find.text('5. Utang'));
    await tester.pumpAndSettle();
    expect(
      find.text('Step 5 of 8: Record credit and repayments'),
      findsOneWidget,
    );
    await tester.tap(find.text('8. Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Open guide'), findsOneWidget);
  });

  testWidgets('all topics fit a small phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const TutorialScreen(),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -2200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (i < 7) await tester.tap(find.text('Next'));
    }
  });
}
