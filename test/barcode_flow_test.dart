import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sari_scan_app/src/app.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/screens/barcode_scanner_screen.dart';
import 'package:sari_scan_app/src/screens/products_screen.dart';
import 'package:sari_scan_app/src/store/app_store.dart';

class _ScannerPlatform extends MobileScannerPlatform {
  bool failStop = false;
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.unavailable,
        size: Size(640, 480),
      );
  @override
  Future<void> stop() async {
    if (failStop) throw PlatformException(code: 'camera_stop_failed');
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> scan(WidgetTester tester, String barcode) async {
  tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
    BarcodeCapture(barcodes: [Barcode(rawValue: barcode)]),
  );
  await tester.pumpAndSettle();
}

Future<void> fillProduct(WidgetTester tester) async {
  for (final entry in {
    'Product Name': 'Test milk',
    'Category': 'Drinks',
    'Cost Price': '10',
    'Initial Stock': '3',
  }.entries) {
    await tester.ensureVisible(field(entry.key));
    await tester.enterText(field(entry.key), entry.value);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    final previous = MobileScannerPlatform.instance;
    MobileScannerPlatform.instance = _ScannerPlatform();
    addTearDown(() => MobileScannerPlatform.instance = previous);
  });

  testWidgets(
    'manual input ignores camera detections and survives a camera stop error',
    (tester) async {
      final store = AppStore(
        products: [
          Product(
            id: '1',
            name: 'Milk',
            category: 'Food',
            price: 10,
            stock: 1,
            barcode: 'AbC-001',
          ),
        ],
      );
      addTearDown(store.dispose);
      await store.openSecureSession('Owner');
      await tester.pumpWidget(SariScanApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Scan barcode'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MobileScanner>(find.byType(MobileScanner)).scanWindow,
        isNotNull,
      );
      await tester.tap(find.text('Enter Manually'));
      await tester.pumpAndSettle();
      await scan(tester, 'WRONG');
      expect(find.byType(BarcodeScannerScreen), findsOneWidget);
      await tester.enterText(field('Barcode number'), ' AbC-001 ');
      (MobileScannerPlatform.instance as _ScannerPlatform).failStop = true;
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pumpAndSettle();
      expect(store.cartItemCount, 1);
      expect(find.text('Barcode not found'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stock limits never report a successful scan addition', (
    tester,
  ) async {
    final product = Product(
      id: '1',
      name: 'Milk',
      category: 'Food',
      price: 10,
      stock: 0,
      barcode: '123',
    );
    final store = AppStore(products: [product]);
    addTearDown(store.dispose);
    await store.openSecureSession('Owner');
    await tester.pumpWidget(SariScanApp(store: store));
    await tester.pumpAndSettle();
    for (final stocked in [false, true]) {
      if (stocked) {
        store.addStock(product: product, quantity: 1, note: 'Delivery');
        store.addToCart(product);
        ScaffoldMessenger.of(
          tester.element(find.byType(Scaffold).first),
        ).removeCurrentSnackBar();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Scan barcode'));
      await tester.pumpAndSettle();
      await scan(tester, '123');
      expect(
        find.text(
          stocked
              ? 'All available stock for Milk is already in the cart.'
              : 'Milk is out of stock.',
        ),
        findsOneWidget,
      );
      expect(store.cartItemCount, stocked ? 1 : 0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'offscreen invalid prices and duplicate barcodes prevent saving',
    (tester) async {
      final store = AppStore(
        products: [
          Product(
            id: '1',
            name: 'Existing',
            category: 'Food',
            price: 10,
            stock: 1,
            barcode: '012345678905',
          ),
        ],
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(MaterialApp(home: ProductDialog(store: store)));
      await tester.pumpAndSettle();
      await fillProduct(tester);
      await tester.ensureVisible(field('Cost Price'));
      await tester.enterText(field('Cost Price'), 'NaN');
      await tester.ensureVisible(field('Barcode (optional)'));
      await tester.enterText(field('Barcode (optional)'), '0012345678905');
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE PRODUCT'));
      await tester.pumpAndSettle();
      expect(store.products, hasLength(1));
      expect(
        find.text('Another active product already uses this barcode.'),
        findsOneWidget,
      );
      await tester.ensureVisible(field('Cost Price'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fromSearch in [false, true]) {
    testWidgets(
      'scan, save, then find product from ${fromSearch ? 'POS' : 'inventory'}',
      (tester) async {
        final store = AppStore();
        addTearDown(store.dispose);
        await store.openSecureSession('Owner');
        await tester.pumpWidget(SariScanApp(store: store));
        await tester.pumpAndSettle();
        if (fromSearch) {
          await tester.tap(find.byTooltip('Scan barcode'));
          await tester.pumpAndSettle();
          await scan(tester, '012345678905');
          await tester.tap(find.text('Add product'));
        } else {
          await tester.tap(find.text('Products').last);
          await tester.pumpAndSettle();
          await tester.tap(find.byType(FloatingActionButton));
        }
        await tester.pumpAndSettle();
        await fillProduct(tester);
        await tester.ensureVisible(field('Barcode (optional)'));
        await tester.pumpAndSettle();
        if (!fromSearch) {
          await tester.tap(find.byTooltip('Scan barcode with camera'));
          await tester.pumpAndSettle();
          await scan(tester, '012345678905');
        }
        await tester.tap(find.text('SAVE PRODUCT'));
        await tester.pumpAndSettle();
        expect(store.products.single.barcode, '012345678905');
        if (!fromSearch) {
          await tester.tap(find.text('POS').last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('Scan barcode'));
        await tester.pumpAndSettle();
        await scan(tester, '0012345678905');
        expect(find.text('Barcode not found'), findsNothing);
        expect(store.cartItemCount, fromSearch ? 2 : 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
