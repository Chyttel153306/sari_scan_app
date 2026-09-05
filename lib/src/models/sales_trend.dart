import 'models.dart';

class SalesTrendPoint {
  const SalesTrendPoint({
    required this.label,
    required this.start,
    required this.end,
    required this.value,
  });

  final String label;
  final DateTime start;
  final DateTime end;
  final double value;
}

DateTime reportStart(ReportPeriod period, DateTime reference) {
  final local = reference.toLocal();
  return switch (period) {
    ReportPeriod.today => DateTime(local.year, local.month, local.day),
    ReportPeriod.week => DateTime(
      local.year,
      local.month,
      local.day - local.weekday + 1,
    ),
    ReportPeriod.month => DateTime(local.year, local.month),
    ReportPeriod.year => DateTime(local.year),
  };
}

List<SalesTrendPoint> buildSalesTrend(
  ReportPeriod period,
  Iterable<SaleRecord> sales, {
  required DateTime now,
}) {
  final start = reportStart(period, now);
  final boundaries = <DateTime>[];
  final labels = <String>[];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  switch (period) {
    case ReportPeriod.today:
      for (var hour = 0; hour <= 24; hour += 4) {
        boundaries.add(DateTime(start.year, start.month, start.day, hour));
      }
      labels.addAll([
        '12–4am',
        '4–8am',
        '8am–12pm',
        '12–4pm',
        '4–8pm',
        '8pm–12am',
      ]);
    case ReportPeriod.week:
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var day = 0; day <= 7; day++) {
        final date = DateTime(start.year, start.month, start.day + day);
        boundaries.add(date);
        if (day < 7) {
          labels.add('${days[day]}\n${date.day} ${months[date.month - 1]}');
        }
      }
    case ReportPeriod.month:
      final days = DateTime(start.year, start.month + 1, 0).day;
      for (var day = 1; day <= days; day += 7) {
        boundaries.add(DateTime(start.year, start.month, day));
        labels.add(
          '$day–${(day + 6).clamp(1, days)} ${months[start.month - 1]}',
        );
      }
      boundaries.add(DateTime(start.year, start.month + 1));
    case ReportPeriod.year:
      for (var month = 1; month <= 13; month++) {
        boundaries.add(DateTime(start.year, month));
      }
      labels.addAll(months);
  }
  final totals = List<double>.filled(labels.length, 0);
  for (final sale in sales) {
    final date = sale.createdAt.toLocal();
    if (date.isAfter(now) ||
        date.isBefore(start) ||
        !date.isBefore(boundaries.last)) {
      continue;
    }
    for (var i = 0; i < labels.length; i++) {
      if (!date.isBefore(boundaries[i]) && date.isBefore(boundaries[i + 1])) {
        totals[i] += sale.total;
        break;
      }
    }
  }
  return List.generate(
    labels.length,
    (i) => SalesTrendPoint(
      label: labels[i],
      start: boundaries[i],
      end: boundaries[i + 1],
      value: totals[i],
    ),
  );
}
