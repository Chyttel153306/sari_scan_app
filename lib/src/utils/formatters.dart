String money(num value) => '₱${value.toStringAsFixed(2)}';

String shortDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hourValue = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.year}-$month-$day $hourValue:$minute $period';
}

String receiptNumber(String id) => 'SS-${id.padLeft(6, '0')}';
