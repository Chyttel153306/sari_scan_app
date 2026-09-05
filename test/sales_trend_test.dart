import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/models/sales_trend.dart';
import 'package:sari_scan_app/src/store/app_store.dart';
import 'package:sari_scan_app/src/widgets/sales_trend_chart.dart';

SaleRecord sale(
  String id,
  DateTime date,
  double total, {
  PaymentType type = PaymentType.cash,
}) => SaleRecord(
  id: id,
  createdAt: date,
  items: const [],
  total: total,
  paymentType: type,
  amountReceived: total,
  change: 0,
);

void main() {
  test(
    'today has exact four-hour buckets and excludes previous/future sales',
    () {
      final now = DateTime(2026, 9, 5, 20);
      final store = AppStore()
        ..sales.addAll([
          sale('old', DateTime(2026, 9, 4, 23, 59), 999),
          sale('1', DateTime(2026, 9, 5), 10),
          sale('2', DateTime(2026, 9, 5, 3, 59), 20),
          sale('3', DateTime(2026, 9, 5, 4), 40, type: PaymentType.utang),
          sale('4', now, 50),
          sale('future', DateTime(2026, 9, 5, 21), 999),
          sale('tomorrow', DateTime(2026, 9, 6), 999),
        ]);
      final records = store.salesFor(ReportPeriod.today, now: now);
      expect(records.map((record) => record.id), ['1', '2', '3', '4']);
      final trend = buildSalesTrend(ReportPeriod.today, store.sales, now: now);
      expect(trend.map((point) => point.value), [30, 40, 0, 0, 0, 50]);
      expect(
        trend.fold<double>(0, (sum, point) => sum + point.value),
        records.fold<double>(0, (sum, record) => sum + record.total),
      );
    },
  );

  test('week starts on Monday across year boundary', () {
    final now = DateTime(2026, 1, 4, 23);
    final records = [
      sale('1', DateTime(2025, 12, 29), 100),
      sale('2', DateTime(2026, 1, 4), 200),
      sale('old', DateTime(2025, 12, 28), 999),
      sale('next', DateTime(2026, 1, 5), 999),
    ];
    final trend = buildSalesTrend(ReportPeriod.week, records, now: now);
    expect(trend.first.label, 'Mon\n29 Dec');
    expect(trend.last.label, 'Sun\n4 Jan');
    expect(trend.map((point) => point.value), [100, 0, 0, 0, 0, 0, 200]);
    final store = AppStore()..sales.addAll(records);
    expect(store.salesFor(ReportPeriod.week, now: now), hasLength(2));
  });

  test('monthly buckets reflect actual day ranges including leap day', () {
    final leap = buildSalesTrend(ReportPeriod.month, [
      sale('leap', DateTime(2024, 2, 29), 80),
      sale('next', DateTime(2024, 3, 1), 999),
    ], now: DateTime(2024, 2, 29, 23));
    expect(leap.last.label, '29–29 Feb');
    expect(leap.last.value, 80);
    final regular = buildSalesTrend(
      ReportPeriod.month,
      [],
      now: DateTime(2025, 2, 28),
    );
    expect(regular, hasLength(4));
    expect(regular.last.end, DateTime(2025, 3, 1));
  });

  test(
    'yearly totals use local months and exclude other years and future dates',
    () {
      final now = DateTime(2026, 9, 5, 20);
      final records = [
        sale('old', DateTime(2025, 12, 31), 999),
        sale('jan', DateTime(2026, 1, 1).toUtc(), 12.25),
        sale('sep', DateTime(2026, 9, 5), 7.75, type: PaymentType.utang),
        sale('future', DateTime(2026, 12, 1), 999),
        sale('next', DateTime(2027, 1, 1), 999),
      ];
      final points = buildSalesTrend(ReportPeriod.year, records, now: now);
      expect(points, hasLength(12));
      expect(points.first.value, 12.25);
      expect(points[8].value, 7.75);
      expect(points.fold<double>(0, (sum, point) => sum + point.value), 20);
      final store = AppStore()..sales.addAll(records);
      expect(store.salesFor(ReportPeriod.year, now: now), hasLength(2));
      expect(store.salesFor(ReportPeriod.month, now: now).single.id, 'sep');
    },
  );

  testWidgets(
    'chart bars are proportional, zero is empty, and taps show exact amounts',
    (tester) async {
      final points = buildSalesTrend(ReportPeriod.today, [
        sale('1', DateTime(2026, 9, 5, 1), 100),
        sale('2', DateTime(2026, 9, 5, 5), 50),
      ], now: DateTime(2026, 9, 5, 20));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SalesTrendChart(points: points)),
        ),
      );
      final full = tester
          .getSize(find.byKey(const ValueKey('sales-bar-0')))
          .height;
      final half = tester
          .getSize(find.byKey(const ValueKey('sales-bar-1')))
          .height;
      expect(full, greaterThan(0));
      expect(half, closeTo(full / 2, 0.001));
      expect(
        tester.getSize(find.byKey(const ValueKey('sales-bar-2'))).height,
        0,
      );
      await tester.tap(find.byKey(const ValueKey('sales-bar-1')));
      await tester.pump();
      expect(find.text('4–8am: ₱50.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
