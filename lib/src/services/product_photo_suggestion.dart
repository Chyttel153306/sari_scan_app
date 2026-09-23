import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/models.dart';

class ProductPhotoSuggestion {
  const ProductPhotoSuggestion({this.name, this.category});

  final String? name;
  final String? category;
}

/// Selects nearby, prominent label text instead of relying on OCR block order.
/// Suggestions preserve recognized spelling and never invent missing words.
ProductPhotoSuggestion suggestProductFromPhoto(
  RecognizedText recognized, {
  required Iterable<Product> products,
}) {
  final lines = [
    for (final block in recognized.blocks)
      for (final line in block.lines)
        if ((line.confidence == null || line.confidence! >= .65) &&
            line.boundingBox.height > 0 &&
            line.boundingBox.width > 0)
          line,
  ];
  final candidates = lines.where((line) => _isName(line.text)).toList();
  if (candidates.isEmpty) return const ProductPhotoSuggestion();

  candidates.sort(
    (a, b) => b.boundingBox.height.compareTo(a.boundingBox.height),
  );
  final anchors = candidates.where(
    (line) => RegExp(r'[A-Za-zéñÉÑ]').hasMatch(line.text),
  );
  if (anchors.isEmpty) return const ProductPhotoSuggestion();
  final anchor = anchors.first;
  final selected = candidates.where((line) {
    final box = line.boundingBox;
    final main = anchor.boundingBox;
    final horizontalOverlap =
        math.min(box.right, main.right) - math.max(box.left, main.left);
    final verticalGap = math.max(
      0.0,
      math.max(box.top - main.bottom, main.top - box.bottom),
    );
    return box.height >= main.height * .4 &&
        horizontalOverlap >= math.min(box.width, main.width) * .3 &&
        verticalGap <= main.height * 2.5;
  }).toList()..sort(_readingOrder);

  final nameParts = <String>[];
  final seen = <String>{};
  for (final line in selected) {
    final text = _clean(line.text);
    if (seen.add(_normalize(text))) nameParts.add(text);
  }
  var name = nameParts.join(' ');
  // Excessive text usually indicates a paragraph, not a front label.
  if (name.length > 100 || nameParts.length > 5) {
    return const ProductPhotoSuggestion();
  }

  // A separately printed net weight helps distinguish otherwise identical SKUs.
  // Ignore serving sizes and multiple conflicting weights.
  if (!_size.hasMatch(name)) {
    final labelBox = selected
        .map((line) => line.boundingBox)
        .reduce((a, b) => a.expandToInclude(b));
    final sizes = <String, String>{};
    for (final line in lines) {
      final text = _clean(line.text);
      if (!_standaloneSize.hasMatch(text)) continue;
      final box = line.boundingBox;
      final overlap =
          math.min(box.right, labelBox.right) -
          math.max(box.left, labelBox.left);
      final gap = math.max(
        0.0,
        math.max(box.top - labelBox.bottom, labelBox.top - box.bottom),
      );
      if (overlap <= 0 || gap > anchor.boundingBox.height * 4) continue;
      final size = _size.firstMatch(text)!.group(0)!;
      sizes[_normalize(size)] = size;
    }
    if (sizes.length == 1) name = '$name ${sizes.values.single}';
  }

  // Only reuse a saved name when all label words and the size agree. Partial
  // word matches can silently substitute a different brand, flavor, or size.
  final normalized = _normalize(name);
  final matches = products
      .where(
        (product) =>
            !product.isArchived && _normalize(product.name) == normalized,
      )
      .toList();
  if (matches.length == 1) {
    return ProductPhotoSuggestion(
      name: matches.single.name,
      category: matches.single.category,
    );
  }
  return ProductPhotoSuggestion(name: name, category: _inferCategory(name));
}

String _clean(String text) =>
    text.replaceAll(RegExp('[™®©]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

String _normalize(String text) => _clean(text)
    .toLowerCase()
    .replaceAllMapped(
      RegExp(r'(\d)\s+(g|kg|ml|l|oz)\b'),
      (match) => '${match[1]}${match[2]}',
    )
    .replaceAll(RegExp(r'[^a-z0-9éñ.]+'), ' ')
    .trim();

final _size = RegExp(
  r'\b\d+(?:[.,]\d+)?\s*(?:kg|mg|g|ml|l|oz)\b',
  caseSensitive: false,
);
final _standaloneSize = RegExp(
  r'^(?:(?:net\s*(?:wt\.?|weight|content|contents|volume)?)[\s:]*|weight[\s:]*)?'
  r'\d+(?:[.,]\d+)?\s*(?:kg|mg|g|ml|l|oz)\.?$',
  caseSensitive: false,
);
final _packagingText = RegExp(
  r'\b(?:nutrition|nutritional|ingredients?|allergens?|servings?|calories|'
  r'sodium|cholesterol|carbohydrates?|total fat|saturated|'
  r'daily value|dietary|contains|manufactured|manufacturer|distributed|'
  r'imported|packed by|product of|made in|best before|expiry|expires|'
  r'expiration|batch|lot|storage|store in|keep in|keep out|refrigerate|'
  r'directions|instructions|preparation|customer|www|https?|recyclable|'
  r'recycle|promo|sale|suggested retail|srp)\b',
  caseSensitive: false,
);

bool _isName(String value) {
  final text = _clean(value);
  if (text.length < 2 ||
      text.length > 60 ||
      _packagingText.hasMatch(text) ||
      _standaloneSize.hasMatch(text) ||
      RegExp(
        r'^(?:buy\s+\d|save\s+\d|\d+\s*%\s*(?:off|free))',
        caseSensitive: false,
      ).hasMatch(text)) {
    return false;
  }
  if (RegExp(
    r'^\d\s*[- ]?in[- ]?\s*\d$',
    caseSensitive: false,
  ).hasMatch(text)) {
    return true;
  }
  // Numeric brands (for example, 555) may support a nearby product label,
  // but a number alone must never become the name anchor.
  if (RegExp(r'^\d{2,3}$').hasMatch(text)) return true;
  if (RegExp(
    r'^(?:energy|protein)\s*[:\d]',
    caseSensitive: false,
  ).hasMatch(text)) {
    return false;
  }
  final letters = RegExp(r'[A-Za-zéñÉÑ]').allMatches(text).length;
  return letters >= 2 && letters / text.length >= .45;
}

int _readingOrder(TextLine a, TextLine b) {
  final boxA = a.boundingBox;
  final boxB = b.boundingBox;
  if ((boxA.center.dy - boxB.center.dy).abs() <
      math.min(boxA.height, boxB.height) * .5) {
    return boxA.left.compareTo(boxB.left);
  }
  return boxA.top.compareTo(boxB.top);
}

String? _inferCategory(String name) {
  final text = ' ${_normalize(name)} ';
  const categories = {
    'Drinks': ['drink', 'juice', 'coffee', 'tea', 'soda', 'water', 'milk'],
    'Snacks': ['snack', 'chips', 'biscuit', 'cookie', 'cracker', 'candy'],
    'Canned Goods': ['canned', 'sardine', 'tuna', 'corned beef'],
    'Pantry': ['rice', 'noodle', 'pasta', 'flour', 'sugar', 'salt'],
    'Personal Care': ['shampoo', 'soap', 'toothpaste', 'lotion'],
    'Household': ['detergent', 'bleach', 'dishwashing', 'tissue'],
  };
  for (final category in categories.entries) {
    if (category.value.any(
      (word) => text.contains(' $word ') || text.contains(' ${word}s '),
    )) {
      return category.key;
    }
  }
  return null;
}
