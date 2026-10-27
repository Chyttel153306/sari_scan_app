/// Formats a number as peso text for screens and receipts.
String money(num value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '₱$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// Formats the supplied date and time without converting its timezone.
String shortDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hourValue = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.year}-$month-$day $hourValue:$minute $period';
}

/// Formats a sale ID as the receipt label used on screen and in exported PDFs.
String receiptNumber(String id) => 'SS-${id.padLeft(6, '0')}';
