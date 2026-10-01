/// Preserve barcode text (including meaningful leading zeros and letter case).
String normalizeBarcode(String value) => value.trim();

/// UPC-A and its zero-prefixed EAN-13 representation identify the same item.
/// Only fold valid retail codes; arbitrary short/custom codes stay distinct.
String barcodeKey(String value) {
  final code = normalizeBarcode(value);
  if (!RegExp(r'^\d{12,13}$').hasMatch(code)) return code;
  var sum = 0;
  for (var i = code.length - 1; i >= 0; i--) {
    sum += (code.codeUnitAt(i) - 48) * ((code.length - 1 - i).isEven ? 1 : 3);
  }
  if (sum % 10 != 0) return code;
  return code.length == 12 ? '0$code' : code;
}

bool matchesBarcodeSearch(String barcode, String query) {
  final normalized = normalizeBarcode(query);
  if (normalized.isEmpty) return false;
  return barcode.toLowerCase().contains(normalized.toLowerCase()) ||
      barcodeKey(barcode) == barcodeKey(normalized);
}
